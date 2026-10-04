classdef ABS_Live < handle
properties
    mdl = 'S4_ESC_Lab'
    projectFolder
    mdlFile
    cacheFolder
    brakeBlock
    brakeHTMLPath
    cfg
    fig
    ui = struct()
    state = struct()
    visual = struct()
    plots = struct()
    slipYMargin = 0.05
    speedYLim = [-1 29]
    torqueYMargin = 50
end
methods
    function obj = ABS_Live()
        obj.projectFolder = fileparts(mfilename('fullpath'));
        obj.mdlFile = fullfile(obj.projectFolder,[obj.mdl '.slx']);
        obj.cacheFolder = fullfile(obj.projectFolder,'cache');
        addpath(obj.projectFolder,'-begin');
        if ~isfile(obj.mdlFile)
            error('S4_ESC_Lab:MissingModel','S4_ESC_Lab.slx must be in the same folder as run_ABS.m, ABS_Live.m, and ABS_Utils.m.');
        end
        if ~isfolder(obj.cacheFolder)
            mkdir(obj.cacheFolder);
        end
        try
            Simulink.fileGenControl('set','CacheFolder',obj.cacheFolder,'CodeGenFolder',obj.cacheFolder,'createDir',true);
        catch
        end
        obj.cfg = ABS_Utils.defaultConfig();
        ABS_Utils.publishVariables(obj.cfg);
        load_system(obj.mdlFile);
        ABS_Utils.configureSignalLogging(obj.mdl);
        obj.brakeBlock = ABS_Utils.findBrakeBlock(obj.mdl);
        set_param(obj.brakeBlock,'Value','0','SampleTime','0');
        obj.brakeHTMLPath = ABS_Utils.ensureBrakeHTML(obj.cacheFolder);
        obj.resetState();
        obj.buildUI();
        setappdata(obj.fig,'ABSApp',obj);
        setappdata(groot,'S4_ABS_LiveApp',obj);
    end
    function delete(obj)
        try
            obj.setBrakeCommand(false);
        catch
        end
        try
            obj.stopLiveTimer();
        catch
        end
        obj.unregisterLiveCallbackTarget();
    end
    function receiveLivePacket(obj,signalID,data,time)
        if isempty(obj.fig) || ~isvalid(obj.fig) || ~isfield(obj.state,'running') || ~obj.state.running
            return;
        end
        if ischar(signalID) || isstring(signalID)
            signalID = str2double(signalID);
        end
        if ~isnumeric(signalID) || ~isscalar(signalID) || ~isfinite(signalID)
            return;
        end
        names = {'V','Vwheel','slip','Tb','x','lambda_ref','lambda_hat','J','pedal'};
        signalID = round(double(signalID));
        if signalID < 1 || signalID > numel(names)
            return;
        end
        try
            values = double(data(:));
            times = double(time(:));
        catch
            return;
        end
        n = min(numel(values),numel(times));
        if n < 1
            return;
        end
        values = values(1:n);
        times = times(1:n);
        valid = isfinite(values) & isfinite(times);
        values = values(valid);
        times = times(valid);
        if isempty(times)
            return;
        end
        key = names{signalID};
        newSamples = times > obj.state.liveTime.(key) + 1e-12;
        values = values(newSamples);
        times = times(newSamples);
        if isempty(times)
            return;
        end
        obj.state.liveBufferValue.(key) = [obj.state.liveBufferValue.(key);values];
        obj.state.liveBufferTime.(key) = [obj.state.liveBufferTime.(key);times];
        obj.state.liveValue.(key) = values(end);
        obj.state.liveTime.(key) = times(end);
        obj.state.livePacketCount.(key) = obj.state.livePacketCount.(key) + 1;
    end
end
methods(Access=private)
    function resetState(obj)
        obj.state.mode = 'closed';
        obj.state.running = false;
        obj.state.paused = false;
        obj.state.finalizing = false;
        obj.state.brakeDown = false;
        obj.state.brakeEverApplied = false;
        obj.state.brakeStartTime = NaN;
        obj.state.brakeStartX = NaN;
        obj.state.eventActive = false;
        obj.state.eventCount = 0;
        obj.state.eventStartTime = NaN;
        obj.state.eventStartX = NaN;
        obj.state.eventStartV = NaN;
        obj.state.eventPeakSlip = 0;
        obj.state.lastSampleTime = -Inf;
        obj.state.lastLiveTime = NaN;
        obj.state.lastUiUpdateTime = -Inf;
        obj.state.uiPeriod = 0.05;
        obj.state.wheelAngle = 0;
        obj.resetLiveBuffer();
        obj.state.hist = ABS_Utils.emptyHistory();
        obj.state.simTimer = [];
        obj.state.liveTimerStart = [];
        obj.state.liveWarningShown = false;
        obj.state.htmlSeq = 0;
    end
    function buildUI(obj)
        oldFig = findall(groot,'Type','figure','Tag','S4_ESC_INTERACTIVE_LAB');
        if ~isempty(oldFig)
            delete(oldFig);
        end
        obj.fig = uifigure('Name','ABS | Interactive Extremum Seeking Control Laboratory','Tag','S4_ESC_INTERACTIVE_LAB','WindowState','maximized','Color',[0.97 0.97 0.97],'CloseRequestFcn',@(s,e)obj.closeApp());
        main = uigridlayout(obj.fig,[2 3]);
        main.ColumnWidth = {420,'1x','1.18x'};
        main.RowHeight = {'0.94x','1.06x'};
        main.Padding = [8 8 8 8];
        main.RowSpacing = 8;
        main.ColumnSpacing = 9;
        controls = uipanel(main,'Title','Controls','FontWeight','bold');
        controls.Layout.Row = [1 2];
        controls.Layout.Column = 1;
        left = uigridlayout(controls,[7 1]);
        left.RowHeight = {62,58,220,145,105,66,'1x'};
        left.Padding = [6 6 6 6];
        left.RowSpacing = 5;
        modePanel = uipanel(left,'Title','Control mode');
        modePanel.Layout.Row = 1;
        mg = uigridlayout(modePanel,[1 2]);
        mg.ColumnWidth = {'1x','1x'};
        mg.Padding = [7 5 7 5];
        mg.ColumnSpacing = 8;
        obj.ui.openBtn = uibutton(mg,'Text','Open Loop','ButtonPushedFcn',@(s,e)obj.setMode('open'));
        obj.ui.closedBtn = uibutton(mg,'Text','Closed Loop (ESC)','ButtonPushedFcn',@(s,e)obj.setMode('closed'));
        roadPanel = uipanel(left,'Title','Road surface');
        roadPanel.Layout.Row = 2;
        rg = uigridlayout(roadPanel,[1 2]);
        rg.ColumnWidth = {95,'1x'};
        rg.Padding = [7 4 7 4];
        uilabel(rg,'Text','Condition','VerticalAlignment','center');
        obj.ui.road = uidropdown(rg,'Items',{'Dry asphalt','Wet asphalt','Snow','Ice'},'Value',obj.cfg.road,'ValueChangedFcn',@(s,e)obj.roadChanged());
        escPanel = uipanel(left,'Title','Extremum Seeking Control');
        escPanel.Layout.Row = 3;
        eg = uigridlayout(escPanel,[6 1]);
        eg.RowHeight = repmat({'1x'},1,6);
        eg.Padding = [5 4 5 4];
        eg.RowSpacing = 2;
        [obj.ui.bSlider,obj.ui.bEdit] = obj.parameterRow(eg,1,sprintf('Modulation amplitude\nb'),[0.002 0.08],obj.cfg.b,'%.3f');
        [obj.ui.wSlider,obj.ui.wEdit] = obj.parameterRow(eg,2,sprintf('Forcing frequency\nomega [rad/s]'),[1 20],obj.cfg.omega,'%.2f');
        [obj.ui.kSlider,obj.ui.kEdit] = obj.parameterRow(eg,3,sprintf('Learning rate\nk'),[0.01 2],obj.cfg.k,'%.3f');
        [obj.ui.whSlider,obj.ui.whEdit] = obj.parameterRow(eg,4,sprintf('HPF cutoff\n[rad/s]'),[0.05 5],obj.cfg.wh,'%.2f');
        [obj.ui.wlSlider,obj.ui.wlEdit] = obj.parameterRow(eg,5,sprintf('LPF cutoff\n[rad/s]'),[0.05 8],obj.cfg.wl,'%.2f');
        [obj.ui.l0Slider,obj.ui.l0Edit] = obj.parameterRow(eg,6,sprintf('Initial\ntheta_hat'),[0.02 0.60],obj.cfg.lambda0,'%.3f');
        brakeMetrics = uigridlayout(left,[1 2]);
        brakeMetrics.Layout.Row = 4;
        brakeMetrics.ColumnWidth = {165,'1x'};
        brakeMetrics.Padding = [0 0 0 0];
        brakeMetrics.ColumnSpacing = 5;
        brakePanel = uipanel(brakeMetrics,'Title','Driver brake');
        brakePanel.Layout.Column = 1;
        bg = uigridlayout(brakePanel,[1 1]);
        bg.Padding = [4 4 4 4];
        obj.ui.brakeHTML = uihtml(bg,'HTMLSource',obj.brakeHTMLPath,'DataChangedFcn',@(src,event)obj.brakeDataChanged(event));
        obj.setBrakeButtonEnabled(false);
        metricPanel = uipanel(brakeMetrics,'Title','Current / last brake event');
        metricPanel.Layout.Column = 2;
        met = uigridlayout(metricPanel,[6 2]);
        met.ColumnWidth = {'1x',58};
        met.RowHeight = repmat({'1x'},1,6);
        met.Padding = [5 2 5 2];
        met.RowSpacing = 0;
        obj.metricLabel(met,'Brake event','eventNumber');
        obj.metricLabel(met,'Hold duration [s]','eventDuration');
        obj.metricLabel(met,'Speed reduction [km/h]','deltaSpeed');
        obj.metricLabel(met,'Distance [m]','eventDistance');
        obj.metricLabel(met,'Peak slip','peakSlip');
        obj.metricLabel(met,'Slip tracking score [%]','slipError');
        simPanel = uipanel(left,'Title','Simulation');
        simPanel.Layout.Row = 5;
        simGrid = uigridlayout(simPanel,[2 3]);
        simGrid.ColumnWidth = {'1x','1x','1x'};
        simGrid.RowHeight = {'1x','1x'};
        simGrid.Padding = [5 4 5 4];
        simGrid.ColumnSpacing = 5;
        simGrid.RowSpacing = 4;
        obj.ui.startBtn = uibutton(simGrid,'Text','Start / Restart','FontWeight','bold','ButtonPushedFcn',@(s,e)obj.startSimulation());
        obj.ui.pauseBtn = uibutton(simGrid,'Text','Pause','Enable','off','ButtonPushedFcn',@(s,e)obj.pauseResumeSimulation());
        obj.ui.stopBtn = uibutton(simGrid,'Text','Stop','Enable','off','ButtonPushedFcn',@(s,e)obj.stopSimulation());
        obj.ui.openModelBtn = uibutton(simGrid,'Text','Open Simulink','ButtonPushedFcn',@(s,e)obj.openModel());
        obj.ui.defaultsBtn = uibutton(simGrid,'Text','Defaults','ButtonPushedFcn',@(s,e)obj.restoreDefaults());
        obj.ui.clearBtn = uibutton(simGrid,'Text','Clear Plots','ButtonPushedFcn',@(s,e)obj.clearPlots());
        pacingPanel = uipanel(left,'Title','Simulation pacing');
        pacingPanel.Layout.Row = 6;
        pg = uigridlayout(pacingPanel,[1 4]);
        pg.ColumnWidth = {68,78,'1x',58};
        pg.Padding = [6 4 6 4];
        pg.ColumnSpacing = 5;
        obj.ui.pacingEnabled = uicheckbox(pg,'Text','Enable','Value',obj.cfg.pacingEnabled,'ValueChangedFcn',@(s,e)obj.pacingChanged());
        uilabel(pg,'Text','Rate [0.1-1x]','HorizontalAlignment','right','VerticalAlignment','center','FontSize',10);
        initialPacing = min(1,max(0.1,obj.cfg.pacingRate));
        obj.ui.pacingRate = uislider(pg,'Limits',[0.1 1],'Value',initialPacing,'MajorTicks',[]);
        obj.ui.pacingRate.ValueChangingFcn = @(s,e)obj.pacingSliderChanging(e.Value);
        obj.ui.pacingRate.ValueChangedFcn = @(s,e)obj.pacingSliderChanged(s.Value);
        obj.ui.pacingRateEdit = uieditfield(pg,'numeric','Limits',[0.1 1],'Value',initialPacing,'ValueDisplayFormat','%.2f','ValueChangedFcn',@(s,e)obj.pacingEditChanged(s.Value));
        statusPanel = uipanel(left,'BorderType','none');
        statusPanel.Layout.Row = 7;
        stg = uigridlayout(statusPanel,[1 1]);
        stg.Padding = [3 2 3 2];
        obj.ui.status = uilabel(stg,'Text','Ready. Start the simulation, then hold BRAKE whenever you want.','HorizontalAlignment','center','FontWeight','bold','WordWrap','on');
        wheelPanel = uipanel(main,'Title','Live wheel / brake assembly');
        wheelPanel.Layout.Row = 1;
        wheelPanel.Layout.Column = 2;
        wg = uigridlayout(wheelPanel,[1 1]);
        wg.Padding = [4 4 4 4];
        obj.ui.axWheel = uiaxes(wg);
        fricPanel = uipanel(main,'Title','Road friction curve and ESC search');
        fricPanel.Layout.Row = 1;
        fricPanel.Layout.Column = 3;
        fg = uigridlayout(fricPanel,[1 1]);
        fg.Padding = [4 4 4 4];
        obj.ui.axFriction = uiaxes(fg);
        slipPanel = uipanel(main,'Title','Live wheel slip and ESC outputs');
        slipPanel.Layout.Row = 2;
        slipPanel.Layout.Column = 2;
        sg = uigridlayout(slipPanel,[1 1]);
        sg.Padding = [4 4 4 4];
        obj.ui.axSlip = uiaxes(sg);
        speedPanel = uipanel(main,'Title','Live vehicle / wheel speeds and brake torque');
        speedPanel.Layout.Row = 2;
        speedPanel.Layout.Column = 3;
        spg = uigridlayout(speedPanel,[1 1]);
        spg.Padding = [4 4 4 4];
        obj.ui.axSpeed = uiaxes(spg);
        obj.setMode('closed');
        obj.pacingChanged();
        obj.resetMetrics();
        obj.initialize3DWheel();
        obj.drawFrictionCurve();
        obj.prepareLivePlots();
        obj.setRunControls(false);
    end
    function setMode(obj,newMode)
        if obj.state.running
            return;
        end
        obj.state.mode = newMode;
        if strcmp(newMode,'closed')
            obj.ui.closedBtn.BackgroundColor = [0.78 0.89 1.00];
            obj.ui.closedBtn.FontWeight = 'bold';
            obj.ui.openBtn.BackgroundColor = [0.96 0.96 0.96];
            obj.ui.openBtn.FontWeight = 'normal';
            obj.setESCEnable('on');
            obj.ui.status.Text = 'Closed Loop: ESC determines the slip reference while the inner PI regulates brake torque.';
        else
            obj.ui.openBtn.BackgroundColor = [1.00 0.88 0.78];
            obj.ui.openBtn.FontWeight = 'bold';
            obj.ui.closedBtn.BackgroundColor = [0.96 0.96 0.96];
            obj.ui.closedBtn.FontWeight = 'normal';
            obj.setESCEnable('off');
            obj.ui.status.Text = 'Open Loop: holding BRAKE applies the fixed open-loop brake torque.';
        end
    end
    function setESCEnable(obj,val)
        objs = {obj.ui.bSlider,obj.ui.bEdit,obj.ui.wSlider,obj.ui.wEdit,obj.ui.kSlider,obj.ui.kEdit,obj.ui.whSlider,obj.ui.whEdit,obj.ui.wlSlider,obj.ui.wlEdit,obj.ui.l0Slider,obj.ui.l0Edit};
        for ii = 1:numel(objs)
            objs{ii}.Enable = val;
        end
    end
    function roadChanged(obj)
        if obj.state.running
            return;
        end
        obj.cfg.road = obj.ui.road.Value;
        [~,obj.cfg.MF] = ABS_Utils.roadParameters(obj.cfg.road);
        obj.drawFrictionCurve();
        obj.prepareLivePlots();
        obj.ui.status.Text = sprintf('Road selected: %s.',obj.ui.road.Value);
    end
    function pacingSliderChanging(obj,val)
        val = min(1,max(0.1,val));
        obj.ui.pacingRateEdit.Value = val;
    end
    function pacingSliderChanged(obj,val)
        val = min(1,max(0.1,val));
        obj.ui.pacingRate.Value = val;
        obj.ui.pacingRateEdit.Value = val;
        obj.pacingChanged();
    end
    function pacingEditChanged(obj,val)
        val = min(1,max(0.1,val));
        obj.ui.pacingRate.Value = val;
        obj.ui.pacingRateEdit.Value = val;
        obj.pacingChanged();
    end
    function pacingChanged(obj)
        if obj.ui.pacingEnabled.Value
            obj.ui.pacingRate.Enable = 'on';
            obj.ui.pacingRateEdit.Enable = 'on';
            if ~obj.state.running
                obj.ui.status.Text = sprintf('Pacing enabled at %.2fx.',obj.ui.pacingRateEdit.Value);
            end
        else
            obj.ui.pacingRate.Enable = 'off';
            obj.ui.pacingRateEdit.Enable = 'off';
            if ~obj.state.running
                obj.ui.status.Text = 'Pacing disabled: simulation runs as fast as possible.';
            end
        end
    end
    function startSimulation(obj)
        try
            obj.ensureStopped();
            obj.stopLiveTimer();
            c = obj.readConfigFromUI();
            obj.cfg = c;
            ABS_Utils.publishVariables(c);
            load_system(obj.mdlFile);
            ABS_Utils.configureSignalLogging(obj.mdl);
            obj.applyPacing(c);
            set_param(obj.mdl,'SimulationMode','normal');
            set_param(obj.mdl,'StopTime','inf');
            set_param(obj.brakeBlock,'Value','0','SampleTime','0');
            obj.state.running = true;
            obj.state.paused = false;
            obj.state.finalizing = false;
            obj.state.brakeDown = false;
            obj.state.brakeEverApplied = false;
            obj.state.brakeStartTime = NaN;
            obj.state.brakeStartX = NaN;
            obj.state.eventActive = false;
            obj.state.eventCount = 0;
            obj.state.eventStartTime = NaN;
            obj.state.eventStartX = NaN;
            obj.state.eventStartV = NaN;
            obj.state.eventPeakSlip = 0;
            obj.state.lastSampleTime = -Inf;
            obj.state.lastLiveTime = NaN;
            obj.state.lastUiUpdateTime = -Inf;
            obj.state.wheelAngle = 0;
            obj.state.hist = ABS_Utils.emptyHistory();
            obj.resetLiveBuffer();
            obj.state.liveWarningShown = false;
            obj.resetMetrics();
            obj.initialize3DWheel();
            obj.drawFrictionCurve();
            obj.prepareLivePlots();
            obj.setRunControls(true);
            obj.ui.status.Text = 'Starting simulation...';
            set_param(obj.mdl,'SimulationCommand','start');
            t0 = tic;
            while toc(t0) < 3
                st = get_param(obj.mdl,'SimulationStatus');
                if strcmp(st,'running') || strcmp(st,'paused')
                    break;
                end
                drawnow;
                pause(0.01);
            end
            st = get_param(obj.mdl,'SimulationStatus');
            if ~strcmp(st,'running')
                error('S4_ESC_Lab:SimulationDidNotStart','The model did not enter the running state.');
            end
            obj.startLiveTimer();
            obj.ui.status.Text = 'Running. Waiting for live signal packets; hold BRAKE whenever you want to brake.';
        catch ME
            obj.state.running = false;
            obj.state.paused = false;
            obj.setRunControls(false);
            obj.ui.status.Text = ['Simulation error: ' ME.message];
            uialert(obj.fig,ME.message,'S4 ABS simulation error','Icon','error');
            fprintf(2,'\n===== S4_ESC_Lab simulation error =====\n%s\n',getReport(ME,'extended','hyperlinks','on'));
        end
    end
    function resetLiveBuffer(obj)
        names = {'V','Vwheel','slip','Tb','x','lambda_ref','lambda_hat','J','pedal'};
        obj.state.liveValue = struct();
        obj.state.liveTime = struct();
        obj.state.livePacketCount = struct();
        obj.state.liveBufferValue = struct();
        obj.state.liveBufferTime = struct();
        for ii = 1:numel(names)
            key = names{ii};
            obj.state.liveValue.(key) = NaN;
            obj.state.liveTime.(key) = -Inf;
            obj.state.livePacketCount.(key) = 0;
            obj.state.liveBufferValue.(key) = zeros(0,1);
            obj.state.liveBufferTime.(key) = zeros(0,1);
        end
    end
    function value = readLiveSignal(obj,name)
        value = NaN;
        if isfield(obj.state,'liveValue') && isfield(obj.state.liveValue,name)
            value = obj.state.liveValue.(name);
        end
    end
    function y = readBufferedSignal(obj,name,tq,defaultValue,method)
        tb = obj.state.liveBufferTime.(name);
        vb = obj.state.liveBufferValue.(name);
        y = defaultValue*ones(size(tq));
        if isempty(tb)
            return;
        end
        [tb,ia] = unique(tb,'stable');
        vb = vb(ia);
        if numel(tb) == 1
            y(tq >= tb(1)) = vb(1);
            return;
        end
        inside = tq >= tb(1) & tq <= tb(end);
        if any(inside)
            y(inside) = interp1(tb,vb,tq(inside),method);
        end
        y(tq > tb(end)) = vb(end);
    end
    function t = liveFrameTime(obj)
        t = NaN;
        if ~isfield(obj.state,'liveTime')
            return;
        end
        critical = {'V','slip','Tb'};
        tt = NaN(1,numel(critical));
        for ii = 1:numel(critical)
            key = critical{ii};
            if isfield(obj.state.liveTime,key)
                tt(ii) = obj.state.liveTime.(key);
            end
        end
        if all(isfinite(tt))
            t = min(tt);
        end
    end
    function missing = missingLiveSignals(obj)
        names = {'V','Vwheel','slip','Tb','x','lambda_ref','lambda_hat','J','pedal'};
        missing = {};
        for ii = 1:numel(names)
            key = names{ii};
            if ~isfield(obj.state,'livePacketCount') || ~isfield(obj.state.livePacketCount,key) || obj.state.livePacketCount.(key) < 1
                missing{end+1} = key; %#ok<AGROW>
            end
        end
    end
    function unregisterLiveCallbackTarget(obj)
        try
            if isappdata(groot,'S4_ABS_LiveApp')
                current = getappdata(groot,'S4_ABS_LiveApp');
                if isequal(current,obj)
                    rmappdata(groot,'S4_ABS_LiveApp');
                end
            end
        catch
        end
    end
    function pauseResumeSimulation(obj)
        if ~obj.state.running
            return;
        end
        try
            st = get_param(obj.mdl,'SimulationStatus');
            if strcmp(st,'running')
                obj.releaseBrake();
                set_param(obj.mdl,'SimulationCommand','pause');
                obj.state.paused = true;
                obj.ui.pauseBtn.Text = 'Resume';
                obj.setBrakeButtonEnabled(false);
                obj.ui.status.Text = 'Simulation paused.';
            elseif strcmp(st,'paused')
                set_param(obj.mdl,'SimulationCommand','continue');
                obj.state.paused = false;
                obj.ui.pauseBtn.Text = 'Pause';
                obj.setBrakeButtonEnabled(true);
                obj.ui.status.Text = 'Simulation resumed.';
            end
        catch ME
            obj.ui.status.Text = ['Pause/resume error: ' ME.message];
        end
    end
    function stopSimulation(obj)
        if ~obj.state.running
            return;
        end
        try
            obj.releaseBrake();
            obj.setBrakeButtonEnabled(false);
            set_param(obj.mdl,'SimulationCommand','stop');
            obj.ui.status.Text = 'Stopping simulation...';
        catch ME
            obj.ui.status.Text = ['Stop error: ' ME.message];
        end
    end
    function brakeDataChanged(obj,event)
        if ~obj.state.running || obj.state.paused
            return;
        end
        d = event.Data;
        pressed = [];
        if isstruct(d) && isfield(d,'pressed')
            pressed = logical(d.pressed);
        elseif islogical(d) && isscalar(d)
            pressed = d;
        elseif isnumeric(d) && isscalar(d)
            pressed = logical(d);
        end
        if isempty(pressed)
            return;
        end
        if pressed
            obj.pressBrake();
        else
            obj.releaseBrake();
        end
    end
    function pressBrake(obj)
        if ~obj.state.running || obj.state.paused || obj.state.brakeDown
            return;
        end
        st = get_param(obj.mdl,'SimulationStatus');
        if ~strcmp(st,'running')
            return;
        end
        Vnow = obj.readLiveSignal('V');
        if ~isfinite(Vnow)
            Vnow = ABS_Utils.previousOr(obj.state.hist.V,obj.cfg.v0);
        end
        if isfinite(Vnow) && Vnow <= obj.restThreshold()
            obj.ui.status.Text = 'The vehicle has reached rest. Press Stop or Restart to begin another run.';
            obj.setBrakeButtonEnabled(false);
            return;
        end
        obj.state.brakeDown = true;
        obj.state.brakeEverApplied = true;
        obj.setBrakeCommand(true);
        obj.updateBrakeVisual(true);
    end
    function releaseBrake(obj)
        wasDown = isfield(obj.state,'brakeDown') && obj.state.brakeDown;
        obj.state.brakeDown = false;
        obj.setBrakeCommand(false);
        obj.updateBrakeVisual(false);
        if wasDown && obj.state.eventActive
            try
                obj.sampleLiveData();
            catch
            end
            obj.finalizeBrakeEvent();
        end
        if isfield(obj.ui,'brakeHTML') && isvalid(obj.ui.brakeHTML)
            obj.state.htmlSeq = obj.state.htmlSeq + 1;
            obj.ui.brakeHTML.Data = struct('enabled',obj.state.running && ~obj.state.paused,'pressed',false,'seq',obj.state.htmlSeq);
        end
    end
    function setBrakeCommand(obj,on)
        if on
            value = '1';
        else
            value = '0';
        end
        try
            set_param(obj.brakeBlock,'Value',value);
        catch ME
            warning('S4_ESC_Lab:BrakeCommand','Could not update Brake Pedal Constant: %s',ME.message);
        end
    end
    function setBrakeButtonEnabled(obj,tf)
        if ~isfield(obj.ui,'brakeHTML') || ~isvalid(obj.ui.brakeHTML)
            return;
        end
        obj.state.htmlSeq = obj.state.htmlSeq + 1;
        obj.ui.brakeHTML.Data = struct('enabled',logical(tf),'pressed',logical(obj.state.brakeDown),'seq',obj.state.htmlSeq);
    end
    function startLiveTimer(obj)
        obj.stopLiveTimer();
        obj.state.liveTimerStart = tic;
        obj.state.simTimer = timer('ExecutionMode','fixedSpacing','Period',0.02,'BusyMode','drop','TimerFcn',@(~,~)obj.liveTick(),'ErrorFcn',@(~,evt)obj.timerError(evt));
        start(obj.state.simTimer);
    end
    function stopLiveTimer(obj)
        if isfield(obj.state,'simTimer') && ~isempty(obj.state.simTimer)
            try
                if isvalid(obj.state.simTimer)
                    stop(obj.state.simTimer);
                    delete(obj.state.simTimer);
                end
            catch
            end
        end
        obj.state.simTimer = [];
    end
    function timerError(obj,evt)
        try
            warning('S4_ESC_Lab:LiveTimer','Live timer error: %s',evt.Data.Message);
        catch
            warning('S4_ESC_Lab:LiveTimer','Live timer error.');
        end
        if isvalid(obj.fig)
            obj.ui.status.Text = 'Live monitor timer reported an error. See Command Window.';
        end
    end
    function liveTick(obj)
        if ~isvalid(obj.fig) || ~obj.state.running
            return;
        end
        try
            st = get_param(obj.mdl,'SimulationStatus');
            if strcmp(st,'stopped') && ~obj.state.finalizing
                obj.finalizeRun();
                return;
            end
            if strcmp(st,'running') && ~obj.state.paused
                t = obj.liveFrameTime();
                if isfinite(t)
                    obj.sampleLiveData(t);
                elseif ~obj.state.liveWarningShown && ~isempty(obj.state.liveTimerStart) && toc(obj.state.liveTimerStart) > 1.0
                    missing = obj.missingLiveSignals();
                    obj.ui.status.Text = sprintf('Waiting for Simulink Data Access packets. Missing: %s',strjoin(missing,', '));
                    obj.state.liveWarningShown = true;
                end
            end
        catch ME
            if obj.state.running && isvalid(obj.fig)
                obj.ui.status.Text = ['Simulation monitor error: ' ME.message];
            end
        end
    end
    function sampleLiveData(obj,t)
        if nargin < 2 || ~isfinite(t)
            t = obj.liveFrameTime();
        end
        if ~isfinite(t)
            return;
        end
        tAll = obj.state.liveBufferTime.V;
        vAll = obj.state.liveBufferValue.V;
        use = tAll > obj.state.lastSampleTime + 1e-10 & tAll <= t + 1e-10;
        tq = tAll(use);
        V = vAll(use);
        if isempty(tq)
            return;
        end
        Vwheel0 = ABS_Utils.previousOr(obj.state.hist.Vwheel,obj.cfg.v0);
        slip0 = ABS_Utils.previousOr(obj.state.hist.slip,0);
        x0 = ABS_Utils.previousOr(obj.state.hist.x,0);
        lambdaRef0 = ABS_Utils.previousOr(obj.state.hist.lambdaRef,obj.cfg.lambda0);
        lambdaHat0 = ABS_Utils.previousOr(obj.state.hist.lambdaHat,obj.cfg.lambda0);
        Tb0 = ABS_Utils.previousOr(obj.state.hist.Tb,0);
        J0 = ABS_Utils.previousOr(obj.state.hist.J,0);
        pedal0 = ABS_Utils.previousOr(obj.state.hist.pedal,0);
        Vwheel = obj.readBufferedSignal('Vwheel',tq,Vwheel0,'linear');
        slip = obj.readBufferedSignal('slip',tq,slip0,'linear');
        x = obj.readBufferedSignal('x',tq,x0,'linear');
        lambdaRef = obj.readBufferedSignal('lambda_ref',tq,lambdaRef0,'linear');
        lambdaHat = obj.readBufferedSignal('lambda_hat',tq,lambdaHat0,'linear');
        Tb = obj.readBufferedSignal('Tb',tq,Tb0,'linear');
        J = obj.readBufferedSignal('J',tq,J0,'linear');
        pedal = obj.readBufferedSignal('pedal',tq,pedal0,'previous');
        previousPedal = ABS_Utils.previousOr(obj.state.hist.pedal,0);
        riseIdx = find(([previousPedal;pedal(1:end-1)] <= 0.5) & (pedal > 0.5),1,'first');
        slipDisplay = max(0,min(1,slip));
        wheelSpeedDisplay = abs(Vwheel);
        obj.state.hist.t = [obj.state.hist.t;tq];
        obj.state.hist.slip = [obj.state.hist.slip;slipDisplay];
        obj.state.hist.V = [obj.state.hist.V;V];
        obj.state.hist.Vwheel = [obj.state.hist.Vwheel;wheelSpeedDisplay];
        obj.state.hist.x = [obj.state.hist.x;x];
        obj.state.hist.lambdaRef = [obj.state.hist.lambdaRef;lambdaRef];
        obj.state.hist.lambdaHat = [obj.state.hist.lambdaHat;lambdaHat];
        obj.state.hist.Tb = [obj.state.hist.Tb;max(0,Tb)];
        obj.state.hist.J = [obj.state.hist.J;J];
        obj.state.hist.pedal = [obj.state.hist.pedal;pedal];
        if ~obj.state.eventActive && ~isempty(riseIdx)
            obj.state.eventActive = true;
            obj.state.eventCount = obj.state.eventCount + 1;
            obj.state.eventStartTime = tq(riseIdx);
            obj.state.eventStartX = x(riseIdx);
            obj.state.eventStartV = V(riseIdx);
            obj.state.eventPeakSlip = max(slipDisplay(riseIdx:end));
            obj.ui.eventNumber.Text = sprintf('%d',obj.state.eventCount);
            obj.ui.eventDuration.Text = '0.00';
            obj.ui.deltaSpeed.Text = '0.0';
            obj.ui.eventDistance.Text = '0.00';
            obj.ui.peakSlip.Text = '0.000';
            obj.ui.slipError.Text = '—';
        elseif obj.state.eventActive
            obj.state.eventPeakSlip = max(obj.state.eventPeakSlip,max(slipDisplay));
        end
        if isnan(obj.state.lastLiveTime)
            if numel(tq) > 1
                dtheta = trapz(tq,wheelSpeedDisplay/max(obj.cfg.Rw,eps));
            else
                dtheta = 0;
            end
        else
            previousWheel = ABS_Utils.previousOr(obj.state.hist.Vwheel(1:end-numel(tq)),wheelSpeedDisplay(1));
            tt = [obj.state.lastLiveTime;tq];
            ww = [previousWheel;wheelSpeedDisplay]/max(obj.cfg.Rw,eps);
            dtheta = trapz(tt,ww);
        end
        obj.state.wheelAngle = mod(obj.state.wheelAngle+dtheta,2*pi);
        obj.state.lastLiveTime = tq(end);
        obj.state.lastSampleTime = tq(end);
        obj.updateLivePlots();
        Vnow = V(end);
        VwheelNow = wheelSpeedDisplay(end);
        slipNow = slipDisplay(end);
        TbNow = Tb(end);
        pedalNow = pedal(end);
        obj.update3DWheel(Vnow,VwheelNow,slipNow,TbNow,pedalNow);
        obj.updateLiveMetrics();
        if obj.state.brakeDown && Vnow <= obj.restThreshold()
            obj.autoReleaseAtRest();
            return;
        end
        lambdaOpt = ABS_Utils.trueOptimum(obj.cfg.MF);
        if pedalNow > 0.5
            brakeText = 'BRAKE ON';
        else
            brakeText = 'BRAKE OFF';
        end
        obj.ui.status.Text = sprintf('Running | t = %.2f s | V = %.1f km/h | %s | lambda = %.3f | lambda_opt = %.3f',tq(end),max(0,Vnow)*3.6,brakeText,slipNow,lambdaOpt);
        drawnow limitrate;
    end
    function autoReleaseAtRest(obj)
        obj.state.brakeDown = false;
        obj.setBrakeCommand(false);
        obj.updateBrakeVisual(false);
        if obj.state.eventActive
            obj.finalizeBrakeEvent();
        end
        obj.setBrakeButtonEnabled(false);
        obj.ui.status.Text = 'Vehicle reached the stop-speed threshold. Press Stop or Restart for a new run.';
    end
    function r = restThreshold(obj)
        r = 0.001;
        try
            if isfield(obj.cfg,'restV') && isfinite(obj.cfg.restV)
                r = obj.cfg.restV;
            elseif isfield(obj.cfg,'stopV') && isfinite(obj.cfg.stopV)
                r = obj.cfg.stopV;
            end
        catch
        end
    end
    function updateLivePlots(obj)
        h = obj.state.hist;
        if isempty(h.t)
            return;
        end
        set(obj.plots.slip,'XData',h.t,'YData',h.slip);
        set(obj.plots.lambdaRef,'XData',h.t,'YData',h.lambdaRef);
        set(obj.plots.lambdaHat,'XData',h.t,'YData',h.lambdaHat);
        set(obj.plots.V,'XData',h.t,'YData',max(0,h.V));
        set(obj.plots.Vwheel,'XData',h.t,'YData',max(0,h.Vwheel));
        set(obj.plots.Tb,'XData',h.t,'YData',h.Tb);
        t = h.t(end);
        leftEdge = max(0,t-15);
        rightEdge = max(10,t+0.25);
        xlim(obj.ui.axSlip,[leftEdge rightEdge]);
        xlim(obj.ui.axSpeed,[leftEdge rightEdge]);
        lambdaOpt = ABS_Utils.trueOptimum(obj.cfg.MF);
        slipMax = max([h.slip;h.lambdaRef;h.lambdaHat;lambdaOpt],[],'omitnan');
        ylim(obj.ui.axSlip,[-obj.slipYMargin slipMax+obj.slipYMargin]);
        torqueMax = max(h.Tb,[],'omitnan');
        if ~isfinite(torqueMax)
            torqueMax = 0;
        end
        yyaxis(obj.ui.axSpeed,'right');
        ylim(obj.ui.axSpeed,[-obj.torqueYMargin torqueMax+obj.torqueYMargin]);
        yyaxis(obj.ui.axSpeed,'left');
        ylim(obj.ui.axSpeed,obj.speedYLim);
        if isgraphics(obj.visual.lambdaHatMarker)
            lh = h.lambdaHat(end);
            if isfinite(lh)
                set(obj.visual.lambdaHatMarker,'XData',lh,'YData',ABS_Utils.magicFormula(lh,obj.cfg.MF),'Visible','on');
            end
        end
        if isgraphics(obj.visual.slipMarker)
            ls = h.slip(end);
            if isfinite(ls)
                set(obj.visual.slipMarker,'XData',ls,'YData',ABS_Utils.magicFormula(ls,obj.cfg.MF),'Visible','on');
            end
        end
    end
    function update3DWheel(obj,V,Vwheel,slip,Tb,pedal)
        if isgraphics(obj.visual.wheelTransform)
            obj.visual.wheelTransform.Matrix = makehgtform('yrotate',-obj.state.wheelAngle);
        end
        obj.updateBrakeVisual(pedal > 0.5);
        if isgraphics(obj.visual.readout)
            obj.visual.readout.String = sprintf('Vehicle: %5.1f km/h   Wheel: %5.1f km/h   Slip: %.3f   T_b: %.0f N m',max(0,V)*3.6,max(0,Vwheel)*3.6,max(0,slip),max(0,Tb));
        end
    end
    function updateBrakeVisual(obj,on)
        if ~isfield(obj.visual,'caliper') || ~isgraphics(obj.visual.caliper)
            return;
        end
        if on
            obj.visual.caliper.FaceColor = [0.82 0.15 0.10];
            obj.visual.pad1.FaceColor = [0.95 0.35 0.10];
            obj.visual.pad2.FaceColor = [0.95 0.35 0.10];
            obj.visual.brakeLabel.String = 'BRAKE ON';
            obj.visual.brakeLabel.Color = [0.80 0.10 0.08];
        else
            obj.visual.caliper.FaceColor = [0.60 0.60 0.62];
            obj.visual.pad1.FaceColor = [0.45 0.45 0.47];
            obj.visual.pad2.FaceColor = [0.45 0.45 0.47];
            obj.visual.brakeLabel.String = 'BRAKE OFF';
            obj.visual.brakeLabel.Color = [0.25 0.25 0.25];
        end
    end
    function updateLiveMetrics(obj)
        if isempty(obj.state.hist.t) || ~obj.state.eventActive
            return;
        end
        t = obj.state.hist.t(end);
        V = obj.state.hist.V(end);
        x = obj.state.hist.x(end);
        obj.ui.eventNumber.Text = sprintf('%d',obj.state.eventCount);
        obj.ui.eventDuration.Text = sprintf('%.2f',max(0,t-obj.state.eventStartTime));
        obj.ui.deltaSpeed.Text = sprintf('%.1f',max(0,obj.state.eventStartV-max(0,V))*3.6);
        obj.ui.eventDistance.Text = sprintf('%.2f',max(0,x-obj.state.eventStartX));
        obj.ui.peakSlip.Text = sprintf('%.3f',obj.state.eventPeakSlip);
        lambdaOpt = ABS_Utils.trueOptimum(obj.cfg.MF);
        eventMask = obj.state.hist.t >= obj.state.eventStartTime + 0.8 & obj.state.hist.pedal > 0.5 & obj.state.hist.V > 2;
        if any(eventMask)
            trackingSlip = obj.state.hist.slip(eventMask);
            relativeRMSE = sqrt(mean(((trackingSlip-lambdaOpt)/max(lambdaOpt,eps)).^2,'omitnan'));
            slipScore = 100/(1 + (relativeRMSE/0.20)^2);
            obj.ui.slipError.Text = sprintf('%.1f %%',slipScore);
        else
            obj.ui.slipError.Text = '—';
        end
    end
    function finalizeBrakeEvent(obj)
        if ~obj.state.eventActive
            return;
        end
        if ~isempty(obj.state.hist.t)
            t = obj.state.hist.t(end);
            V = obj.state.hist.V(end);
            x = obj.state.hist.x(end);
            obj.ui.eventNumber.Text = sprintf('%d',obj.state.eventCount);
            obj.ui.eventDuration.Text = sprintf('%.3f',max(0,t-obj.state.eventStartTime));
            obj.ui.deltaSpeed.Text = sprintf('%.1f',max(0,obj.state.eventStartV-max(0,V))*3.6);
            obj.ui.eventDistance.Text = sprintf('%.2f',max(0,x-obj.state.eventStartX));
            obj.ui.peakSlip.Text = sprintf('%.3f',obj.state.eventPeakSlip);
            lambdaOpt = ABS_Utils.trueOptimum(obj.cfg.MF);
            eventMask = obj.state.hist.t >= obj.state.eventStartTime + 0.8 & obj.state.hist.pedal > 0.5 & obj.state.hist.V > 2;
            if any(eventMask)
                trackingSlip = obj.state.hist.slip(eventMask);
                relativeRMSE = sqrt(mean(((trackingSlip-lambdaOpt)/max(lambdaOpt,eps)).^2,'omitnan'));
                slipScore = 100/(1 + (relativeRMSE/0.20)^2);
                obj.ui.slipError.Text = sprintf('%.1f %%',slipScore);
            else
                obj.ui.slipError.Text = '—';
            end
        end
        obj.state.eventActive = false;
    end
    function finalizeRun(obj)
        if obj.state.finalizing
            return;
        end
        obj.state.finalizing = true;
        if obj.state.eventActive
            obj.finalizeBrakeEvent();
        end
        obj.stopLiveTimer();
        obj.setBrakeCommand(false);
        obj.state.brakeDown = false;
        obj.updateBrakeVisual(false);
        obj.setBrakeButtonEnabled(false);
        obj.showFullHistory();
        obj.state.running = false;
        obj.state.paused = false;
        obj.setRunControls(false);
        obj.ui.status.Text = 'Simulation stopped by the user.';
        obj.state.finalizing = false;
    end
    function showFullHistory(obj)
        if isempty(obj.state.hist.t)
            return;
        end
        tEnd = max(5,obj.state.hist.t(end));
        xlim(obj.ui.axSlip,[0 tEnd]);
        xlim(obj.ui.axSpeed,[0 tEnd]);
    end
    function initialize3DWheel(obj)
        ax = obj.ui.axWheel;
        cla(ax);
        hold(ax,'on');
        axis(ax,'equal');
        axis(ax,'vis3d');
        view(ax,32,18);
        xlim(ax,[-0.52 0.52]);
        ylim(ax,[-0.45 0.45]);
        zlim(ax,[-0.48 0.54]);
        ax.XTick = [];
        ax.YTick = [];
        ax.ZTick = [];
        ax.Box = 'on';
        ax.Color = [0.96 0.96 0.97];
        [xr,yr] = meshgrid(linspace(-0.60,0.60,2),linspace(-0.55,0.55,2));
        zr = -0.365*ones(size(xr));
        surf(ax,xr,yr,zr,'FaceColor',[0.55 0.55 0.55],'EdgeColor','none');
        for xx = -0.55:0.18:0.55
            plot3(ax,[xx xx+0.08],[-0.52 -0.30],[-0.358 -0.358],'Color',[0.85 0.85 0.35],'LineWidth',2);
        end
        obj.visual.wheelTransform = hgtransform('Parent',ax);
        u = linspace(0,2*pi,64);
        v = linspace(0,2*pi,24);
        [U,Vv] = meshgrid(u,v);
        R = 0.285;
        r = 0.065;
        X = (R+r*cos(Vv)).*cos(U);
        Y = r*sin(Vv);
        Z = (R+r*cos(Vv)).*sin(U);
        surf('XData',X,'YData',Y,'ZData',Z,'Parent',obj.visual.wheelTransform,'FaceColor',[0.08 0.08 0.09],'EdgeColor','none','FaceLighting','gouraud');
        [Xd,Yd,Zd] = ABS_Utils.discCylinder(0.215,0.022,72);
        surf('XData',Xd,'YData',Yd,'ZData',Zd,'Parent',obj.visual.wheelTransform,'FaceColor',[0.63 0.65 0.68],'EdgeColor',[0.45 0.45 0.45],'FaceAlpha',0.95);
        [Xh,Yh,Zh] = ABS_Utils.discCylinder(0.07,0.05,48);
        surf('XData',Xh,'YData',Yh,'ZData',Zh,'Parent',obj.visual.wheelTransform,'FaceColor',[0.18 0.18 0.20],'EdgeColor','none');
        spokeR = 0.235;
        for a = 0:pi/3:(2*pi-pi/3)
            line('XData',[0 spokeR*cos(a)],'YData',[0 0],'ZData',[0 spokeR*sin(a)],'LineWidth',5,'Color',[0.72 0.72 0.74],'Parent',obj.visual.wheelTransform);
        end
        obj.visual.caliper = ABS_Utils.cuboidPatch(ax,[0.205 0.105 0.030],[0.105 0.10 0.17],[0.60 0.60 0.62]);
        obj.visual.pad1 = ABS_Utils.cuboidPatch(ax,[0.205 0.044 0.030],[0.075 0.018 0.12],[0.45 0.45 0.47]);
        obj.visual.pad2 = ABS_Utils.cuboidPatch(ax,[0.205 -0.044 0.030],[0.075 0.018 0.12],[0.45 0.45 0.47]);
        quiver3(ax,-0.42,-0.34,0.42,0.40,0,0,'LineWidth',2,'MaxHeadSize',0.35,'Color',[0.10 0.35 0.75]);
        text(ax,-0.42,-0.34,0.47,'Vehicle direction','FontWeight','bold','Color',[0.10 0.35 0.75]);
        obj.visual.readout = text(ax,0,0,0.48,'Vehicle: 100.0 km/h   Wheel: 100.0 km/h   Slip: 0.000   T_b: 0 N m','HorizontalAlignment','center','FontWeight','bold','FontSize',11);
        obj.visual.brakeLabel = text(ax,0.28,0.18,0.25,'BRAKE OFF','HorizontalAlignment','center','FontWeight','bold','FontSize',11,'Color',[0.25 0.25 0.25]);
        title(ax,'Live one-wheel ABS visualization');
        try
            camlight(ax,'headlight');
            lighting(ax,'gouraud');
        catch
        end
        hold(ax,'off');
    end
    function drawFrictionCurve(obj)
        ax = obj.ui.axFriction;
        [road,MF] = ABS_Utils.roadParameters(obj.ui.road.Value);
        lam = linspace(0,1,1001);
        mu = ABS_Utils.magicFormula(lam,MF);
        [muMax,ix] = max(mu);
        lambdaOpt = lam(ix);
        cla(ax);
        hold(ax,'on');
        plot(ax,lam,mu,'LineWidth',1.8,'DisplayName','mu(lambda)');
        plot(ax,lambdaOpt,muMax,'ko','MarkerFaceColor',[0.15 0.15 0.15],'DisplayName',sprintf('true optimum = %.3f',lambdaOpt));
        obj.visual.lambdaHatMarker = plot(ax,NaN,NaN,'s','MarkerSize',9,'LineWidth',1.5,'DisplayName','ESC theta hat');
        obj.visual.slipMarker = plot(ax,NaN,NaN,'o','MarkerSize',8,'LineWidth',1.3,'DisplayName','actual slip');
        xlabel(ax,'Slip ratio lambda');
        ylabel(ax,'Friction coefficient mu');
        title(ax,road);
        xlim(ax,[0 1]);
        ylim(ax,[0 max(1.08,1.12*max(mu))]);
        grid(ax,'on');
        legend(ax,'Location','best');
        hold(ax,'off');
    end
    function prepareLivePlots(obj)
        ax = obj.ui.axSlip;
        cla(ax);
        hold(ax,'on');
        obj.plots.slip = plot(ax,NaN,NaN,'LineWidth',1.7,'DisplayName','Actual slip lambda');
        obj.plots.lambdaRef = plot(ax,NaN,NaN,'--','LineWidth',1.35,'DisplayName','lambda ref');
        obj.plots.lambdaHat = plot(ax,NaN,NaN,':','LineWidth',1.8,'DisplayName','theta hat');
        lambdaOpt = ABS_Utils.trueOptimum(obj.cfg.MF);
        obj.plots.lambdaOpt = yline(ax,lambdaOpt,'-.','LineWidth',1.2,'DisplayName',sprintf('true optimum = %.3f',lambdaOpt));
        xlabel(ax,'Time [s]');
        ylabel(ax,'Slip ratio');
        title(ax,'ESC slip search');
        ylim(ax,[-obj.slipYMargin lambdaOpt+obj.slipYMargin]);
        xlim(ax,[0 10]);
        grid(ax,'on');
        legend(ax,[obj.plots.slip obj.plots.lambdaRef obj.plots.lambdaHat obj.plots.lambdaOpt],{'Actual slip lambda','lambda ref','theta hat',sprintf('true optimum = %.3f',lambdaOpt)},'Location','best');
        hold(ax,'off');
        ax = obj.ui.axSpeed;
        yyaxis(ax,'left');
        cla(ax);
        yyaxis(ax,'right');
        cla(ax);
        yyaxis(ax,'left');
        hold(ax,'on');
        obj.plots.V = plot(ax,NaN,NaN,'LineWidth',1.6);
        obj.plots.Vwheel = plot(ax,NaN,NaN,'--','LineWidth',1.4);
        ylabel(ax,'Speed [m/s]');
        ylim(ax,obj.speedYLim);
        yyaxis(ax,'right');
        hold(ax,'on');
        obj.plots.Tb = plot(ax,NaN,NaN,':','LineWidth',1.3);
        ylabel(ax,'Brake torque [N m]');
        ylim(ax,[-obj.torqueYMargin obj.torqueYMargin]);
        xlabel(ax,'Time [s]');
        title(ax,'Vehicle speed, wheel speed and brake torque');
        xlim(ax,[0 10]);
        grid(ax,'on');
        legend(ax,[obj.plots.V obj.plots.Vwheel obj.plots.Tb],{'Vehicle speed','Wheel peripheral speed','Brake torque'},'Location','best');
        hold(ax,'off');
    end
    function resetMetrics(obj)
        obj.ui.eventNumber.Text = '—';
        obj.ui.eventDuration.Text = '—';
        obj.ui.deltaSpeed.Text = '—';
        obj.ui.eventDistance.Text = '—';
        obj.ui.peakSlip.Text = '—';
        obj.ui.slipError.Text = '—';
    end
    function setRunControls(obj,isRunning)
        if isRunning
            obj.ui.startBtn.Enable = 'off';
            obj.ui.pauseBtn.Enable = 'on';
            obj.ui.stopBtn.Enable = 'on';
            obj.setBrakeButtonEnabled(true);
            obj.ui.openModelBtn.Enable = 'off';
            obj.ui.defaultsBtn.Enable = 'off';
            obj.ui.clearBtn.Enable = 'off';
            obj.ui.openBtn.Enable = 'off';
            obj.ui.closedBtn.Enable = 'off';
            obj.ui.road.Enable = 'off';
            obj.ui.pacingEnabled.Enable = 'off';
            obj.ui.pacingRate.Enable = 'off';
            obj.ui.pacingRateEdit.Enable = 'off';
            obj.setESCEnable('off');
        else
            obj.ui.startBtn.Enable = 'on';
            obj.ui.pauseBtn.Enable = 'off';
            obj.ui.pauseBtn.Text = 'Pause';
            obj.ui.stopBtn.Enable = 'off';
            obj.setBrakeButtonEnabled(false);
            obj.ui.openModelBtn.Enable = 'on';
            obj.ui.defaultsBtn.Enable = 'on';
            obj.ui.clearBtn.Enable = 'on';
            obj.ui.openBtn.Enable = 'on';
            obj.ui.closedBtn.Enable = 'on';
            obj.ui.road.Enable = 'on';
            obj.ui.pacingEnabled.Enable = 'on';
            obj.pacingChanged();
            if strcmp(obj.state.mode,'closed')
                obj.setESCEnable('on');
            else
                obj.setESCEnable('off');
            end
        end
    end
    function applyPacing(obj,c)
        try
            if c.pacingEnabled
                set_param(obj.mdl,'EnablePacing','on','PacingRate',num2str(c.pacingRate,'%.3f'));
            else
                set_param(obj.mdl,'EnablePacing','off');
            end
        catch ME
            warning('S4_ESC_Lab:Pacing','Could not configure pacing: %s',ME.message);
        end
    end
    function openModel(obj)
        if obj.state.running
            return;
        end
        c = obj.readConfigFromUI();
        ABS_Utils.publishVariables(c);
        load_system(obj.mdlFile);
        ABS_Utils.configureSignalLogging(obj.mdl);
        obj.applyPacing(c);
        open_system(obj.mdl);
    end
    function restoreDefaults(obj)
        if obj.state.running
            return;
        end
        cfg0 = ABS_Utils.defaultConfig();
        obj.cfg = cfg0;
        obj.ui.road.Value = cfg0.road;
        ABS_Utils.setPair(obj.ui.bSlider,obj.ui.bEdit,cfg0.b);
        ABS_Utils.setPair(obj.ui.wSlider,obj.ui.wEdit,cfg0.omega);
        ABS_Utils.setPair(obj.ui.kSlider,obj.ui.kEdit,cfg0.k);
        ABS_Utils.setPair(obj.ui.whSlider,obj.ui.whEdit,cfg0.wh);
        ABS_Utils.setPair(obj.ui.wlSlider,obj.ui.wlEdit,cfg0.wl);
        ABS_Utils.setPair(obj.ui.l0Slider,obj.ui.l0Edit,cfg0.lambda0);
        pacing0 = min(1,max(0.1,cfg0.pacingRate));
        obj.ui.pacingEnabled.Value = cfg0.pacingEnabled;
        obj.ui.pacingRate.Value = pacing0;
        obj.ui.pacingRateEdit.Value = pacing0;
        obj.setMode('closed');
        obj.state.hist = ABS_Utils.emptyHistory();
        obj.state.brakeEverApplied = false;
        obj.state.eventActive = false;
        obj.state.eventCount = 0;
        obj.state.wheelAngle = 0;
        obj.resetMetrics();
        obj.initialize3DWheel();
        obj.drawFrictionCurve();
        obj.prepareLivePlots();
        obj.pacingChanged();
        obj.ui.status.Text = 'Defaults restored.';
    end
    function clearPlots(obj)
        if obj.state.running
            return;
        end
        obj.state.hist = ABS_Utils.emptyHistory();
        obj.resetMetrics();
        obj.initialize3DWheel();
        obj.drawFrictionCurve();
        obj.prepareLivePlots();
        obj.ui.status.Text = 'Plots cleared.';
    end
    function c = readConfigFromUI(obj)
        c = ABS_Utils.defaultConfig();
        c.road = obj.ui.road.Value;
        c.b = obj.ui.bEdit.Value;
        c.omega = obj.ui.wEdit.Value;
        c.k = obj.ui.kEdit.Value;
        c.wh = obj.ui.whEdit.Value;
        c.wl = obj.ui.wlEdit.Value;
        c.lambda0 = obj.ui.l0Edit.Value;
        c.mode = strcmp(obj.state.mode,'closed');
        c.pacingEnabled = obj.ui.pacingEnabled.Value;
        c.pacingRate = min(1,max(0.1,obj.ui.pacingRateEdit.Value));
        [~,c.MF] = ABS_Utils.roadParameters(c.road);
    end
    function ensureStopped(obj)
        if ~bdIsLoaded(obj.mdl)
            load_system(obj.mdlFile);
            return;
        end
        st = get_param(obj.mdl,'SimulationStatus');
        if ~strcmp(st,'stopped')
            try
                obj.setBrakeCommand(false);
                set_param(obj.mdl,'SimulationCommand','stop');
            catch
            end
            t0 = tic;
            while toc(t0) < 3
                drawnow;
                pause(0.02);
                if strcmp(get_param(obj.mdl,'SimulationStatus'),'stopped')
                    break;
                end
            end
        end
    end
    function closeApp(obj)
        try
            obj.setBrakeCommand(false);
        catch
        end
        try
            if bdIsLoaded(obj.mdl) && ~strcmp(get_param(obj.mdl,'SimulationStatus'),'stopped')
                set_param(obj.mdl,'SimulationCommand','stop');
            end
        catch
        end
        obj.stopLiveTimer();
        obj.unregisterLiveCallbackTarget();
        if isvalid(obj.fig)
            delete(obj.fig);
        end
    end
    function [slider,edit] = parameterRow(obj,parent,row,labelText,limits,value,fmt)
        gRow = uigridlayout(parent,[1 5]);
        gRow.Layout.Row = row;
        gRow.ColumnWidth = {105,30,'1x',27,58};
        gRow.Padding = [2 1 2 1];
        gRow.ColumnSpacing = 4;
        uilabel(gRow,'Text',labelText,'VerticalAlignment','center','WordWrap','on','FontSize',10);
        uilabel(gRow,'Text',sprintf('%.3g',limits(1)),'HorizontalAlignment','right','VerticalAlignment','center','FontSize',9);
        slider = uislider(gRow,'Limits',limits,'Value',value,'MajorTicks',[]);
        uilabel(gRow,'Text',sprintf('%.3g',limits(2)),'HorizontalAlignment','left','VerticalAlignment','center','FontSize',9);
        edit = uieditfield(gRow,'numeric','Limits',limits,'Value',value,'ValueDisplayFormat',fmt);
        slider.ValueChangingFcn = @(s,e)obj.sliderChanging(edit,e.Value);
        slider.ValueChangedFcn = @(s,e)obj.sliderChanged(edit,s.Value);
        edit.ValueChangedFcn = @(s,e)obj.editChanged(slider,s.Value);
    end
    function sliderChanging(~,edit,val)
        edit.Value = val;
    end
    function sliderChanged(~,edit,val)
        edit.Value = val;
    end
    function editChanged(~,slider,val)
        slider.Value = val;
    end
    function metricLabel(obj,parent,labelText,fieldName)
        uilabel(parent,'Text',labelText,'VerticalAlignment','center','FontSize',10);
        obj.ui.(fieldName) = uilabel(parent,'Text','—','FontWeight','bold','HorizontalAlignment','right','VerticalAlignment','center','FontSize',10);
    end
end
end