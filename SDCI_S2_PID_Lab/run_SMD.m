% =========================================================================
% MaIA_SDCI - Semana 2: PID
% Sistemas de Decision y Control Inteligente
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
%
% Simscape plant model adapted from:
% R. Abbas, "Modeling and Simulation of Spring Mass Damper System (SMD),"
% MATLAB Central File Exchange, version 1.0.0, Sep. 2, 2021.
% Available: https://www.mathworks.com/matlabcentral/fileexchange/98689-modeling-and-simulation-of-spring-mass-damper-system-smd
% Accessed: Sep. 27, 2026.
% =========================================================================

% Interactive PID laboratory for a mass-spring-damper system.
% Reference and PID gains can be changed while the simulation is running.

function run_SMD

%% Project
mdl = 'SMD_System';
projectFolder = fileparts(mfilename('fullpath'));
mdlFile = fullfile(projectFolder,[mdl '.slx']);
cacheFolder = fullfile(projectFolder,'cache');
if ~isfile(mdlFile)
    error('Cannot find %s in the same folder as run_SMD.m.',[mdl '.slx']);
end
if ~isfolder(cacheFolder)
    mkdir(cacheFolder);
end
try
% Store generated Simulink files in the cache folder.
    Simulink.fileGenControl('set',...
        'CacheFolder',cacheFolder,...
        'CodeGenFolder',cacheFolder,...
        'createDir',true);
catch ME
    warning('Could not configure the cache folder: %s',ME.message);
end
addpath(projectFolder,'-begin');
if bdIsLoaded(mdl)
    try
        loadedFile = get_param(mdl,'FileName');
        if ~isempty(loadedFile) && ~strcmpi(char(loadedFile),mdlFile)
            if ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
                set_param(mdl,'SimulationCommand','stop');
                waitForStatus(mdl,'stopped',5);
            end
            close_system(mdl,0);
        end
    catch
    end
end
load_system(mdlFile);

%% Model blocks
refBlock = findBlockByName(mdl,'Reference Input',1);
pidBlock = findBlockByName(mdl,'PID Controller',1);
simscapeBlock = findBlockByName(mdl,'Simscape Plant Model',1);

guiSampleBlock = findBlockByName(simscapeBlock,'GUI Sample',1);
massBlock = findBlockByName(simscapeBlock,'Attached Mass',1);
damperBlock = findBlockByName(simscapeBlock,'Damper',1);
springBlock = findBlockByName(simscapeBlock,'Spring',1);
forceConverterBlock = findBlockByName(simscapeBlock,'Simulink-PS Converter',1);
positionConverterBlock = findBlockByName(simscapeBlock,'PS-Simulink Converter',1);

%% Parameters
p.m = 3.6;                     % kg
p.b = 100;                     % N*s/m
p.k = 400;                     % N/m
p.Kp = 0;
p.Ki = 326.6586;
p.Kd = 0;
p.Nf = 100;
p.x_ref = 1;                   % m
p.refMin = -2;
p.refMax = 2;
p.guiSampleTime = 0.02;        % 50 Hz GUI sampling
p.plotWindow = 30;             % s
p.plotLead = 4;               % s of empty space shown to the right of current time
p.plotYLim = [-3 3];           % m
p.maxPlotPoints = 12000;
p.maxStep = 0.01;              % s
p.pacingRate = 1;
p.settlingThreshold = 0.02;     % 2% settling band
p.settlingHoldTime = 1.0;       % s continuously inside the band before reporting ts
p.steadyWindow = 1.0;           % s used to estimate steady-state error
p.steadyVariation = 0.005;      % 0.5% of step amplitude over steadyWindow
p.metricMinStep = 1e-4;         % m; smaller changes are ignored as experiments

%% Runtime state
state.listener = [];
state.monitor = [];
state.running = false;
state.currentRef = p.x_ref;
state.lastRefPlotValue = p.x_ref;
state.lastFrameTime = -inf;
state.lastSimulationTime = 0;
state.framePeriod = 1/30;
state.refUpdateClock = tic;
state.pidUpdateClock = tic;
state.lastPosition = 0;
state.committedRef = p.x_ref;
state.metric.active = false;
state.metric.t0 = 0;
state.metric.x0 = 0;
state.metric.target = p.x_ref;
state.metric.amplitude = 0;
state.metric.direction = 1;
state.metric.t = [];
state.metric.y = [];
state.metric.overshoot = NaN;
state.metric.peakTime = NaN;
state.metric.settlingTime = NaN;
state.metric.steadyError = NaN;
ui = struct();
publishBaseVariables();
configureModel();

%% GUI
oldFig = findall(groot,'Type','figure','Tag','SMD_PID_INTERACTIVE_LAB');
if ~isempty(oldFig)
    delete(oldFig);
end
fig = uifigure(...
    'Name','Mass-Spring-Damper | Interactive PID Laboratory',...
    'Tag','SMD_PID_INTERACTIVE_LAB',...
    'WindowState','maximized',...
    'Color',[0.97 0.97 0.97],...
    'CloseRequestFcn',@closeApp);
main = uigridlayout(fig,[2 2]);
main.ColumnWidth = {430,'1x'};
main.RowHeight = {'1.08x','0.92x'};
main.Padding = [8 8 8 8];
main.RowSpacing = 8;
main.ColumnSpacing = 10;
controlPanel = uipanel(main,'Title','Controls','FontWeight','bold');
controlPanel.Layout.Row = [1 2];
controlPanel.Layout.Column = 1;
left = uigridlayout(controlPanel,[5 1]);
left.RowHeight = {'1.00x','0.82x','2.15x','1.08x','1.18x'};
left.Padding = [6 6 6 6];
left.RowSpacing = 6;

% Physical model
plantPanel = uipanel(left,'Title','Physical model');
plantPanel.Layout.Row = 1;
plantGrid = uigridlayout(plantPanel,[3 2]);
plantGrid.ColumnWidth = {'1x',112};
plantGrid.RowHeight = {'1x','1x','1x'};
plantGrid.Padding = [8 6 8 6];
plantGrid.RowSpacing = 4;
plantGrid.ColumnSpacing = 10;
uilabel(plantGrid,'Text','Mass m [kg]','VerticalAlignment','center');
ui.mEdit = uieditfield(plantGrid,'numeric','Value',p.m,'Limits',[0.01 Inf],...
    'ValueDisplayFormat','%.4g');
uilabel(plantGrid,'Text','Damping b [N s/m]','VerticalAlignment','center');
ui.bEdit = uieditfield(plantGrid,'numeric','Value',p.b,'Limits',[0 Inf],...
    'ValueDisplayFormat','%.4g');
uilabel(plantGrid,'Text','Spring k [N/m]','VerticalAlignment','center');
ui.kEdit = uieditfield(plantGrid,'numeric','Value',p.k,'Limits',[0.01 Inf],...
    'ValueDisplayFormat','%.4g');

% Position reference
refPanel = uipanel(left,'Title','Position reference — LIVE');
refPanel.Layout.Row = 2;
refGrid = uigridlayout(refPanel,[1 2]);
refGrid.ColumnWidth = {'1x',105};
refGrid.RowHeight = {'1x'};
refGrid.Padding = [8 10 8 6];
refGrid.ColumnSpacing = 10;
ui.refSlider = uislider(refGrid,'Limits',[p.refMin p.refMax],'Value',p.x_ref,...
    'MajorTicks',[-2 -1 0 1 2],'MinorTicks',-2:0.2:2,...
    'ValueChangingFcn',@(s,e)referenceChanging(e.Value),...
    'ValueChangedFcn',@(s,e)referenceChanged(s.Value));
ui.refSlider.Layout.Column = 1;
ui.refEdit = uieditfield(refGrid,'numeric','Value',p.x_ref,...
    'Limits',[p.refMin p.refMax],'ValueDisplayFormat','%.3f',...
    'ValueChangedFcn',@(s,e)referenceEditChanged(s.Value));
ui.refEdit.Layout.Column = 2;

% PID controller
pidPanel = uipanel(left,'Title','PID controller — LIVE');
pidPanel.Layout.Row = 3;
pidGrid = uigridlayout(pidPanel,[5 1]);
pidGrid.RowHeight = {'1x','1x','1x','1x',34};
pidGrid.Padding = [6 6 6 6];
pidGrid.RowSpacing = 3;
[ui.kpSlider,ui.kpEdit] = createPIDRow(pidGrid,1,'Kp',[0 2000],p.Kp,...
    [0 500 1000 1500 2000],'Kp');
[ui.kiSlider,ui.kiEdit] = createPIDRow(pidGrid,2,'Ki',[0 1500],p.Ki,...
    [0 375 750 1125 1500],'Ki');
[ui.kdSlider,ui.kdEdit] = createPIDRow(pidGrid,3,'Kd',[0 150],p.Kd,...
    [0 25 50 100 150],'Kd');
[ui.nSlider,ui.nEdit] = createPIDRow(pidGrid,4,'N',[1 500],p.Nf,...
    [1 100 200 300 400 500],'Nf');
ui.resetPidButton = uibutton(pidGrid,'Text','Reset PID','ButtonPushedFcn',@resetPid);
ui.resetPidButton.Layout.Row = 5;

% Performance metrics
metricsPanel = uipanel(left,'Title','Step-response metrics — 2% band');
metricsPanel.Layout.Row = 4;
metricsGrid = uigridlayout(metricsPanel,[4 2]);
metricsGrid.ColumnWidth = {'1x',105};
metricsGrid.RowHeight = {'1x','1x','1x','1x'};
metricsGrid.Padding = [8 5 8 5];
metricsGrid.RowSpacing = 1;
metricsGrid.ColumnSpacing = 10;

uilabel(metricsGrid,'Text','Overshoot [%]','VerticalAlignment','center');
ui.metricOvershoot = uilabel(metricsGrid,'Text','—','FontWeight','bold',...
    'HorizontalAlignment','right','VerticalAlignment','center');

uilabel(metricsGrid,'Text','Peak time [s]','VerticalAlignment','center');
ui.metricPeakTime = uilabel(metricsGrid,'Text','—','FontWeight','bold',...
    'HorizontalAlignment','right','VerticalAlignment','center');

uilabel(metricsGrid,'Text','Settling time [s]','VerticalAlignment','center');
ui.metricSettlingTime = uilabel(metricsGrid,'Text','—','FontWeight','bold',...
    'HorizontalAlignment','right','VerticalAlignment','center');

uilabel(metricsGrid,'Text','Steady-state error [m]','VerticalAlignment','center');
ui.metricSteadyError = uilabel(metricsGrid,'Text','—','FontWeight','bold',...
    'HorizontalAlignment','right','VerticalAlignment','center');

% Simulation controls
runPanel = uipanel(left,'Title','Simulation');
runPanel.Layout.Row = 5;
runGrid = uigridlayout(runPanel,[3 1]);
runGrid.RowHeight = {'1x','1x',26};
runGrid.Padding = [6 6 6 6];
runGrid.RowSpacing = 5;
buttons = uigridlayout(runGrid,[1 3]);
buttons.Layout.Row = 1;
buttons.ColumnWidth = {'1x','1x','1x'};
buttons.Padding = [0 0 0 0];
buttons.ColumnSpacing = 7;
ui.runButton = uibutton(buttons,'Text','Run / Restart','FontWeight','bold',...
    'ButtonPushedFcn',@runSimulation);
ui.pauseButton = uibutton(buttons,'Text','Pause','ButtonPushedFcn',@pauseResumeSimulation);
ui.stopButton = uibutton(buttons,'Text','Stop','ButtonPushedFcn',@stopSimulation);
ui.openButton = uibutton(runGrid,'Text','Open Simulink','ButtonPushedFcn',@openModel);
ui.openButton.Layout.Row = 2;
ui.status = uilabel(runGrid,'Text','Ready','FontWeight','bold','FontSize',10,...
    'HorizontalAlignment','center','VerticalAlignment','center');
ui.status.Layout.Row = 3;

% Mechanical view
animPanel = uipanel(main,'Title','2-D mechanical view');
animPanel.Layout.Row = 1;
animPanel.Layout.Column = 2;
animGrid = uigridlayout(animPanel,[1 1]);
animGrid.Padding = [8 8 8 8];
ui.axAnim = uiaxes(animGrid);
ui.axAnim.Toolbar.Visible = 'off';
ui.axAnim.Interactions = [];

% Position response
plotPanel = uipanel(main,'Title','Position response');
plotPanel.Layout.Row = 2;
plotPanel.Layout.Column = 2;
plotGrid = uigridlayout(plotPanel,[1 1]);
plotGrid.Padding = [8 8 8 8];
ui.axPlot = uiaxes(plotGrid);
ui.axPlot.Toolbar.Visible = 'off';
ui.axPlot.Interactions = [];
buildMechanicalView();
resetResponsePlot();

fig.SizeChangedFcn = @resizeInterface;
resizeInterface();
resetMetricDisplay();
state.monitor = timer('ExecutionMode','fixedSpacing','Period',0.25,...
    'BusyMode','drop','TimerFcn',@monitorSimulation);
start(state.monitor);

%% Callbacks
    function runSimulation(~,~)
        try
            stopIfNeeded();
            validateInputs();
            setStatus('Preparing...');
            drawnow;
            publishBaseVariables();
            configureModel();
            applyPlantValues();
            applyReferenceValue(ui.refEdit.Value,true);
            applyPidValues(true);
            resetMechanicalView();
            resetResponsePlot();
            state.lastFrameTime = -inf;
            state.lastSimulationTime = 0;
            state.lastPosition = 0;
            state.lastRefPlotValue = state.currentRef;
            state.committedRef = state.currentRef;
            beginStepMetrics(0,0,state.currentRef);
            setPlantControlsEnabled(false);
            setStatus('Compiling...');
            drawnow;
            set_param(mdl,'SimulationCommand','update');
            set_param(mdl,'SimulationCommand','start');
            if ~waitForStatus(mdl,'running',10)
                error('The model did not enter the running state. Check the Diagnostic Viewer.');
            end
            set_param(mdl,'SimulationCommand','pause');
            if ~waitForStatus(mdl,'paused',3)
                error('The model could not be paused while attaching the GUI listener.');
            end
            deleteListener();
            state.listener = add_exec_event_listener(guiSampleBlock,'PostOutputs',@onSimulationFrame);
            state.running = true;
            ui.pauseButton.Text = 'Pause';
            set_param(mdl,'SimulationCommand','continue');
            setStatus('Running | t = 0.00 s');
        catch ME
            try
                if ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
                    set_param(mdl,'SimulationCommand','stop');
                end
            catch
            end
            deleteListener();
            state.running = false;
            setPlantControlsEnabled(true);
            setStatus('Error');
            warning('%s',getReport(ME,'extended','hyperlinks','off'));
            uialert(fig,ME.message,'Simulation error');
        end
    end
    function pauseResumeSimulation(~,~)
        if ~bdIsLoaded(mdl)
            return;
        end
        status = get_param(mdl,'SimulationStatus');
        switch status
            case 'running'
                set_param(mdl,'SimulationCommand','pause');
                ui.pauseButton.Text = 'Continue';
                setStatus(sprintf('Paused | t = %.2f s',state.lastSimulationTime));
            case 'paused'
                set_param(mdl,'SimulationCommand','continue');
                ui.pauseButton.Text = 'Pause';
                setStatus(sprintf('Running | t = %.2f s',state.lastSimulationTime));
        end
    end
    function stopSimulation(~,~)
        if bdIsLoaded(mdl) && ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
            set_param(mdl,'SimulationCommand','stop');
            waitForStatus(mdl,'stopped',5);
        end
        deleteListener();
        state.running = false;
        setPlantControlsEnabled(true);
        ui.pauseButton.Text = 'Pause';
        setStatus('Stopped');
    end
    function openModel(~,~)
        open_system(mdl);
    end
    function resetPid(~,~)
        ui.kpSlider.Value = p.Kp;
        ui.kpEdit.Value = p.Kp;
        ui.kiSlider.Value = p.Ki;
        ui.kiEdit.Value = p.Ki;
        ui.kdSlider.Value = p.Kd;
        ui.kdEdit.Value = p.Kd;
        ui.nSlider.Value = p.Nf;
        ui.nEdit.Value = p.Nf;
        applyPidValues(true);
    end

% Reference
    function referenceChanging(value)
        value = min(max(value,p.refMin),p.refMax);
        ui.refEdit.Value = value;
        updateReferenceMarker(value);
    end
    function referenceChanged(value)
        ui.refEdit.Value = value;
        commitReference(value);
    end
    function referenceEditChanged(value)
        value = min(max(value,p.refMin),p.refMax);
        ui.refSlider.Value = value;
        ui.refEdit.Value = value;
        commitReference(value);
    end
    function commitReference(value)
        value = min(max(value,p.refMin),p.refMax);
        previousCommittedRef = state.committedRef;
        applyReferenceValue(value,true);
        state.committedRef = value;
        if abs(value-previousCommittedRef) >= p.metricMinStep
            status = get_param(mdl,'SimulationStatus');
            if strcmp(status,'running') || strcmp(status,'paused')
                beginStepMetrics(state.lastSimulationTime,state.lastPosition,value);
            else
                resetMetricState();
            end
        end
    end
    function applyReferenceValue(value,forceWrite)
        value = min(max(value,p.refMin),p.refMax);
        state.currentRef = value;
        assignin('base','x_ref',value);
        updateReferenceMarker(value);
        shouldWrite = forceWrite || toc(state.refUpdateClock) >= 0.04;
        if shouldWrite
            state.refUpdateClock = tic;
            set_param(refBlock,'Value',num2str(value,16));
        end
    end

% PID
    function pidSliderChanging(name,value)
        setPidValue(name,value,true);
        applyPidValues(false);
    end
    function pidSliderChanged(name,value)
        setPidValue(name,value,true);
        applyPidValues(true);
    end
    function pidEditChanged(name,value)
        setPidValue(name,value,false);
        applyPidValues(true);
    end
    function setPidValue(name,value,fromSlider)
        switch name
            case 'Kp'
                value = max(0,value);
                ui.kpEdit.Value = value;
                if ~fromSlider, ui.kpSlider.Value = min(value,ui.kpSlider.Limits(2)); end
            case 'Ki'
                value = max(0,value);
                ui.kiEdit.Value = value;
                if ~fromSlider, ui.kiSlider.Value = min(value,ui.kiSlider.Limits(2)); end
            case 'Kd'
                value = max(0,value);
                ui.kdEdit.Value = value;
                if ~fromSlider, ui.kdSlider.Value = min(value,ui.kdSlider.Limits(2)); end
            case 'Nf'
                value = max(1,value);
                ui.nEdit.Value = value;
                if ~fromSlider, ui.nSlider.Value = min(value,ui.nSlider.Limits(2)); end
        end
    end
    function applyPidValues(forceWrite)
        vals = getPidValues();
        assignin('base','Kp',vals.Kp);
        assignin('base','Ki',vals.Ki);
        assignin('base','Kd',vals.Kd);
        assignin('base','Nf',vals.Nf);
        shouldWrite = forceWrite || toc(state.pidUpdateClock) >= 0.04;
        if shouldWrite
            state.pidUpdateClock = tic;
            set_param(pidBlock,...
                'P',num2str(vals.Kp,16),...
                'I',num2str(vals.Ki,16),...
                'D',num2str(vals.Kd,16),...
                'N',num2str(vals.Nf,16));
        end
    end
    function vals = getPidValues()
        vals.Kp = ui.kpEdit.Value;
        vals.Ki = ui.kiEdit.Value;
        vals.Kd = ui.kdEdit.Value;
        vals.Nf = ui.nEdit.Value;
    end

%% Live output
    function onSimulationFrame(block,~)
        if ~isvalid(fig)
            return;
        end
        try
            t = double(block.CurrentTime);
            x = block.OutputPort(1).Data;
            if isempty(x)
                return;
            end
            x = double(x(1));
            if ~isfinite(t) || ~isfinite(x)
                return;
            end
            state.lastSimulationTime = t;
            state.lastPosition = x;
            updateStepMetrics(t,x);
            if t-state.lastFrameTime < state.framePeriod
                return;
            end
            state.lastFrameTime = t;
            activeRef = state.currentRef;
            if abs(activeRef-state.lastRefPlotValue) > 1e-12
                addpoints(ui.referenceLine,t,state.lastRefPlotValue);
                addpoints(ui.referenceLine,t,activeRef);
                state.lastRefPlotValue = activeRef;
            else
                addpoints(ui.referenceLine,t,activeRef);
            end
            addpoints(ui.responseLine,t,x);
            updateMechanicalView(x);
            advancePlotWindow(t);
            setStatus(sprintf('Running | t = %.2f s',t));
            drawnow limitrate nocallbacks;
        catch ME
            warning('GUI frame update skipped: %s',ME.message);
        end
    end

%% Step-response metrics
    function beginStepMetrics(t0,x0,target)
        resetMetricState();
        delta = target-x0;
        if abs(delta) < p.metricMinStep
            return;
        end
        state.metric.active = true;
        state.metric.t0 = t0;
        state.metric.x0 = x0;
        state.metric.target = target;
        state.metric.amplitude = abs(delta);
        state.metric.direction = sign(delta);
        state.metric.t = 0;
        state.metric.y = x0;
        updateMetricDisplay();
    end
    function resetMetricState()
        state.metric.active = false;
        state.metric.t0 = state.lastSimulationTime;
        state.metric.x0 = state.lastPosition;
        state.metric.target = state.currentRef;
        state.metric.amplitude = 0;
        state.metric.direction = 1;
        state.metric.t = [];
        state.metric.y = [];
        state.metric.overshoot = NaN;
        state.metric.peakTime = NaN;
        state.metric.settlingTime = NaN;
        state.metric.steadyError = NaN;
        resetMetricDisplay();
    end
    function resetMetricDisplay()
        if isfield(ui,'metricOvershoot') && isvalid(ui.metricOvershoot)
            ui.metricOvershoot.Text = '—';
            ui.metricPeakTime.Text = '—';
            ui.metricSettlingTime.Text = '—';
            ui.metricSteadyError.Text = '—';
        end
    end
    function updateStepMetrics(t,x)
        if ~state.metric.active
            return;
        end
        tau = max(0,t-state.metric.t0);
        if ~isempty(state.metric.t) && tau <= state.metric.t(end)+1e-10
            return;
        end
        state.metric.t(end+1) = tau;
        state.metric.y(end+1) = x;
        tt = state.metric.t;
        yy = state.metric.y;
        target = state.metric.target;
        amp = state.metric.amplitude;
        direction = state.metric.direction;
        beyondTarget = direction*(yy-target);

        % Overshoot and peak time
        [peakBeyond,idxPeak] = max(beyondTarget);
        if peakBeyond > 0
            state.metric.overshoot = 100*peakBeyond/amp;
            state.metric.peakTime = tt(idxPeak);
        else
            state.metric.overshoot = 0;
            state.metric.peakTime = NaN;
        end

        % Settling time (2% band)
        band = max(p.settlingThreshold*amp,1e-5);
        outside = find(abs(yy-target) > band);
        if isempty(outside)
            candidate = 0;
        elseif outside(end) < numel(tt)
            candidate = tt(outside(end)+1);
        else
            candidate = NaN;
        end
        if isfinite(candidate) && (tt(end)-candidate) >= p.settlingHoldTime
            state.metric.settlingTime = candidate;
        else
            state.metric.settlingTime = NaN;
        end

        % Steady-state error
        if tt(end) >= p.steadyWindow
            idxSteady = tt >= tt(end)-p.steadyWindow;
            ySteady = yy(idxSteady);
            allowedVariation = max(p.steadyVariation*amp,1e-5);
            if ~isempty(ySteady) && (max(ySteady)-min(ySteady)) <= allowedVariation
                state.metric.steadyError = abs(target-mean(ySteady));
            else
                state.metric.steadyError = NaN;
            end
        else
            state.metric.steadyError = NaN;
        end
        updateMetricDisplay();
    end
    function updateMetricDisplay()
        if ~isfield(ui,'metricOvershoot') || ~isvalid(ui.metricOvershoot)
            return;
        end
        if state.metric.active
            if isfinite(state.metric.overshoot)
                ui.metricOvershoot.Text = sprintf('%.2f',state.metric.overshoot);
            else
                ui.metricOvershoot.Text = '—';
            end
            if isfinite(state.metric.peakTime)
                ui.metricPeakTime.Text = sprintf('%.3f',state.metric.peakTime);
            else
                ui.metricPeakTime.Text = '—';
            end
            if isfinite(state.metric.settlingTime)
                ui.metricSettlingTime.Text = sprintf('%.3f',state.metric.settlingTime);
            else
                ui.metricSettlingTime.Text = '—';
            end
            if isfinite(state.metric.steadyError)
                ui.metricSteadyError.Text = sprintf('%.4f',state.metric.steadyError);
            else
                ui.metricSteadyError.Text = '—';
            end
        else
            resetMetricDisplay();
        end
    end

%% Model configuration
    function publishBaseVariables()
        assignin('base','m',uiValueOrDefault('m',p.m));
        assignin('base','b',uiValueOrDefault('b',p.b));
        assignin('base','k',uiValueOrDefault('k',p.k));
        assignin('base','Kp',p.Kp);
        assignin('base','Ki',p.Ki);
        assignin('base','Kd',p.Kd);
        assignin('base','Nf',p.Nf);
        assignin('base','x_ref',state.currentRef);
    end
    function value = uiValueOrDefault(name,defaultValue)
        value = defaultValue;
        if exist('ui','var') && isstruct(ui)
            switch name
                case 'm'
                    if isfield(ui,'mEdit') && isvalid(ui.mEdit), value = ui.mEdit.Value; end
                case 'b'
                    if isfield(ui,'bEdit') && isvalid(ui.bEdit), value = ui.bEdit.Value; end
                case 'k'
                    if isfield(ui,'kEdit') && isvalid(ui.kEdit), value = ui.kEdit.Value; end
            end
        end
    end
    function configureModel()
        set_param(mdl,'FastRestart','off');
        set_param(mdl,'StopTime','inf');
        set_param(mdl,'SimulationMode','normal');
        set_param(mdl,'BlockReduction','off');
        set_param(mdl,'MaxStep',num2str(p.maxStep,16));
        try
            set_param(mdl,'EnablePacing','on','PacingRate',num2str(p.pacingRate));
        catch
            try
                set_param(mdl,'EnablePacing','on');
            catch
            end
        end
        % Physical signal units.
        set_param(forceConverterBlock,'Unit','N');
        set_param(positionConverterBlock,'Unit','m');
        set_param(guiSampleBlock,'SampleTime',num2str(p.guiSampleTime,16));
    end
    function applyPlantValues()
        assignin('base','m',ui.mEdit.Value);
        assignin('base','b',ui.bEdit.Value);
        assignin('base','k',ui.kEdit.Value);
        set_param(massBlock,'mass','m');
        set_param(damperBlock,'D','b');
        set_param(springBlock,'spr_rate','k');
    end
    function validateInputs()
        if ui.mEdit.Value <= 0 || ui.kEdit.Value <= 0 || ui.bEdit.Value < 0
            error('Use m > 0, k > 0 and b >= 0.');
        end
    end

%% Mechanical view
    function buildMechanicalView()
        ax = ui.axAnim;
        cla(ax);
        hold(ax,'on');
        axis(ax,'equal');
        xlim(ax,[-0.2 9.1]);
        ylim(ax,[-0.15 3.15]);
        ax.XTick = [];
        ax.YTick = [];
        ax.Box = 'off';
        ax.Color = [1 1 1];
        g.wallX = 0.20;
        g.springAnchor = 0.40;
        g.massLeft0 = 4.85;
        g.motionScale = 1.20;
        g.massW = 1.20;
        g.massH = 1.50;
        g.massBottom = 0.42;
        g.springY = 1.55;
        g.springAmp = 0.18;
        g.springCoils = 9;
        g.damperY = 0.78;
        g.bodyLeft = 0.72;
        g.bodyW = 1.30;
        g.bodyH = 0.40;
        g.pistonBase = 1.30;
        g.wheelR = 0.115;
        state.geo = g;
        plot(ax,[-0.05 8.90],[0.16 0.16],'LineWidth',2.7,'Color',[0.18 0.18 0.18]);
        for xh = 0.02:0.30:8.75
            plot(ax,[xh xh+0.16],[0.16 0.02],'LineWidth',0.8,'Color',[0.72 0.72 0.72]);
        end
        plot(ax,[g.wallX g.wallX],[0.16 2.78],'LineWidth',5,'Color',[0.16 0.16 0.16]);
        for yh = 0.25:0.22:2.72
            plot(ax,[g.wallX-0.18 g.wallX],[yh-0.11 yh],'LineWidth',1.0,'Color',[0.65 0.65 0.65]);
        end
        plot(ax,[g.wallX g.springAnchor],[g.springY g.springY],...
            'LineWidth',2.5,'Color',[0.12 0.12 0.12]);
        [xs,ys] = springShape(g.springAnchor,g.massLeft0,g.springY,g.springCoils,g.springAmp);
        ui.spring = plot(ax,xs,ys,'LineWidth',2.8,'Color',[0.80 0.43 0.05]);
        ui.springLabel = text(ax,(g.springAnchor+g.massLeft0)/2,g.springY+0.30,'k',...
            'HorizontalAlignment','center','VerticalAlignment','middle',...
            'FontWeight','bold','FontSize',18,'Color',[0.68 0.32 0.02]);
        plot(ax,[g.wallX g.bodyLeft],[g.damperY g.damperY],...
            'LineWidth',3.0,'Color',[0.20 0.20 0.20]);
        ui.damperBody = rectangle(ax,'Position',...
            [g.bodyLeft g.damperY-g.bodyH/2 g.bodyW g.bodyH],...
            'Curvature',[0.10 0.10],'FaceColor',[0.72 0.75 0.78],...
            'EdgeColor',[0.18 0.18 0.18],'LineWidth',1.6);
        ui.damperLabel = text(ax,g.bodyLeft+g.bodyW/2,g.damperY+0.30,'b',...
            'HorizontalAlignment','center','VerticalAlignment','middle',...
            'FontWeight','bold','FontSize',18,'Color',[0.20 0.20 0.20]);
        ui.piston = plot(ax,[g.pistonBase g.pistonBase],...
            [g.damperY-0.15 g.damperY+0.15],...
            'LineWidth',4.0,'Color',[0.18 0.18 0.18]);
        ui.rod = plot(ax,[g.pistonBase g.massLeft0],[g.damperY g.damperY],...
            'LineWidth',4.0,'Color',[0.42 0.44 0.47]);
        ui.mass = rectangle(ax,'Position',...
            [g.massLeft0 g.massBottom g.massW g.massH],...
            'Curvature',[0.04 0.04],'FaceColor',[0.16 0.43 0.74],...
            'EdgeColor',[0.08 0.16 0.25],'LineWidth',1.8);
        ui.wheel1 = rectangle(ax,'Position',...
            [g.massLeft0+0.15,0.15,2*g.wheelR,2*g.wheelR],...
            'Curvature',[1 1],'FaceColor',[0.15 0.15 0.15],...
            'EdgeColor',[0.05 0.05 0.05]);
        ui.wheel2 = rectangle(ax,'Position',...
            [g.massLeft0+g.massW-0.15-2*g.wheelR,0.15,2*g.wheelR,2*g.wheelR],...
            'Curvature',[1 1],'FaceColor',[0.15 0.15 0.15],...
            'EdgeColor',[0.05 0.05 0.05]);
        ui.massLabel = text(ax,g.massLeft0+g.massW/2,g.massBottom+g.massH/2,'m',...
            'HorizontalAlignment','center','VerticalAlignment','middle',...
            'FontWeight','bold','FontSize',24,'Color',[1 1 1]);

        % Position scale shown in the animation.
        scaleY = 2.70;
        scaleValues = -2:1:2;
        scaleX = g.massLeft0 + g.massW/2 + g.motionScale*scaleValues;
        plot(ax,[scaleX(1) scaleX(end)],[scaleY scaleY],...
            'Color',[0.45 0.45 0.45],'LineWidth',1.1);
        for ii = 1:numel(scaleValues)
            plot(ax,[scaleX(ii) scaleX(ii)],[scaleY-0.08 scaleY+0.08],...
                'Color',[0.45 0.45 0.45],'LineWidth',1.1);
            text(ax,scaleX(ii),scaleY+0.11,sprintf('%g',scaleValues(ii)),...
                'HorizontalAlignment','center','VerticalAlignment','bottom',...
                'FontSize',11,'Color',[0.30 0.30 0.30]);
        end
        text(ax,mean(scaleX),scaleY+0.30,'Position [m]',...
            'HorizontalAlignment','center','VerticalAlignment','bottom',...
            'FontWeight','bold','FontSize',12,'Color',[0.30 0.30 0.30]);
        ui.refMarker = plot(ax,[0 0],[0.22 2.70],'--','LineWidth',1.3,...
            'Color',[0.48 0.48 0.48]);
        ui.refText = text(ax,0,2.66,'x_r','HorizontalAlignment','center',...
            'VerticalAlignment','bottom','FontWeight','bold','FontSize',18,...
            'Color',[0.30 0.30 0.30]);
        resetMechanicalView();
    end
    function resetMechanicalView()
        updateMechanicalView(0);
        updateReferenceMarker(state.currentRef);
    end
    function updateMechanicalView(x)
        g = state.geo;
        massLeft = g.massLeft0 + g.motionScale*x;
        set(ui.mass,'Position',[massLeft g.massBottom g.massW g.massH]);
        set(ui.massLabel,'Position',[massLeft+g.massW/2 g.massBottom+g.massH/2 0]);
        set(ui.wheel1,'Position',[massLeft+0.15,0.15,2*g.wheelR,2*g.wheelR]);
        set(ui.wheel2,'Position',[massLeft+g.massW-0.15-2*g.wheelR,0.15,2*g.wheelR,2*g.wheelR]);
        [xs,ys] = springShape(g.springAnchor,massLeft,g.springY,g.springCoils,g.springAmp);
        set(ui.spring,'XData',xs,'YData',ys);
        set(ui.springLabel,'Position',[(g.springAnchor+massLeft)/2 g.springY+0.30 0]);
        bodyMin = g.bodyLeft + 0.12;
        bodyMax = g.bodyLeft + g.bodyW - 0.12;
        pistonX = g.pistonBase + 0.30*g.motionScale*x;
        pistonX = min(max(pistonX,bodyMin),bodyMax);
        set(ui.piston,'XData',[pistonX pistonX]);
        set(ui.rod,'XData',[pistonX massLeft],'YData',[g.damperY g.damperY]);
    end
    function updateReferenceMarker(refValue)
        g = state.geo;
        refX = g.massLeft0 + g.motionScale*refValue + g.massW/2;
        set(ui.refMarker,'XData',[refX refX]);
        set(ui.refText,'Position',[refX 2.66 0]);
    end

%% Response plot
    function resetResponsePlot()
        cla(ui.axPlot);
        hold(ui.axPlot,'on');
        grid(ui.axPlot,'on');
        xlabel(ui.axPlot,'Time [s]');
        ylabel(ui.axPlot,'Position [m]');
        xlim(ui.axPlot,[0 p.plotWindow]);
        ylim(ui.axPlot,p.plotYLim);
        ui.referenceLine = animatedline(ui.axPlot,'LineWidth',1.5,...
            'LineStyle','--','MaximumNumPoints',p.maxPlotPoints,...
            'Color',[0.45 0.45 0.45],'DisplayName','Reference');
        ui.responseLine = animatedline(ui.axPlot,'LineWidth',2.0,...
            'MaximumNumPoints',p.maxPlotPoints,'Color',[0.08 0.08 0.08],...
            'DisplayName','Output');
        addpoints(ui.referenceLine,0,state.currentRef);
        addpoints(ui.responseLine,0,0);
        state.lastRefPlotValue = state.currentRef;
        legend(ui.axPlot,'show','Location','northwest');
    end
    function advancePlotWindow(t)
        % Keep empty space to the right of the current time.
        movingStartTime = p.plotWindow - p.plotLead;

        if t <= movingStartTime
            xlim(ui.axPlot,[0 p.plotWindow]);
        else
            xlim(ui.axPlot,[t-movingStartTime t+p.plotLead]);
        end

        ylim(ui.axPlot,p.plotYLim);
    end

%% UI helpers
    function [slider,edit] = createPIDRow(parent,row,labelText,limits,value,ticks,name)
        rowGrid = uigridlayout(parent,[1 3]);
        rowGrid.Layout.Row = row;
        rowGrid.ColumnWidth = {42,'1x',95};
        rowGrid.Padding = [0 0 0 0];
        rowGrid.ColumnSpacing = 7;
        label = uilabel(rowGrid,'Text',labelText,'FontWeight','bold',...
            'VerticalAlignment','center');
        label.Layout.Column = 1;
        slider = uislider(rowGrid,'Limits',limits,'Value',value,...
            'MajorTicks',ticks,...
            'ValueChangingFcn',@(s,e)pidSliderChanging(name,e.Value),...
            'ValueChangedFcn',@(s,e)pidSliderChanged(name,s.Value));
        slider.Layout.Column = 2;
        edit = uieditfield(rowGrid,'numeric','Value',value,'Limits',[limits(1) Inf],...
            'ValueDisplayFormat','%.5g',...
            'ValueChangedFcn',@(s,e)pidEditChanged(name,s.Value));
        edit.Layout.Column = 3;
    end
    function setPlantControlsEnabled(tf)
        if tf, en = 'on'; else, en = 'off'; end
        ui.mEdit.Enable = en;
        ui.bEdit.Enable = en;
        ui.kEdit.Enable = en;
    end
    function setStatus(message)
        if isvalid(ui.status)
            ui.status.Text = message;
        end
    end
    function resizeInterface(~,~)
        if ~isvalid(fig)
            return;
        end

        % Adapt the control column to the screen size.
        figWidth = fig.Position(3);
        leftWidth = round(0.285*figWidth);
        leftWidth = min(max(leftWidth,400),470);
        main.ColumnWidth = {leftWidth,'1x'};

        figHeight = fig.Position(4);
        if figHeight < 800
            main.Padding = [5 5 5 5];
            main.RowSpacing = 6;
            main.ColumnSpacing = 8;
            left.Padding = [4 4 4 4];
            left.RowSpacing = 4;
            pidGrid.RowSpacing = 2;
            runGrid.RowSpacing = 3;
        else
            main.Padding = [8 8 8 8];
            main.RowSpacing = 8;
            main.ColumnSpacing = 10;
            left.Padding = [6 6 6 6];
            left.RowSpacing = 6;
            pidGrid.RowSpacing = 3;
            runGrid.RowSpacing = 5;
        end
    end

%% Simulation lifecycle
    function monitorSimulation(~,~)
        if ~isvalid(fig) || ~bdIsLoaded(mdl)
            return;
        end
        try
            status = get_param(mdl,'SimulationStatus');
            if strcmp(status,'stopped') && state.running
                state.running = false;
                deleteListener();
                setPlantControlsEnabled(true);
                ui.pauseButton.Text = 'Pause';
                setStatus('Stopped');
            elseif strcmp(status,'paused')
                ui.pauseButton.Text = 'Continue';
            elseif strcmp(status,'running')
                ui.pauseButton.Text = 'Pause';
            end
        catch
        end
    end
    function stopIfNeeded()
        if ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
            set_param(mdl,'SimulationCommand','stop');
            if ~waitForStatus(mdl,'stopped',5)
                error('The previous simulation could not be stopped.');
            end
        end
        deleteListener();
        state.running = false;
    end
    function deleteListener()
        if ~isempty(state.listener)
            try
                delete(state.listener);
            catch
            end
            state.listener = [];
        end
    end
    function closeApp(~,~)
        try
            if bdIsLoaded(mdl) && ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
                set_param(mdl,'SimulationCommand','stop');
                waitForStatus(mdl,'stopped',3);
            end
        catch
        end
        deleteListener();
        if ~isempty(state.monitor) && isvalid(state.monitor)
            try
                stop(state.monitor);
                delete(state.monitor);
            catch
            end
        end
        fig.CloseRequestFcn = '';
        delete(fig);
    end

%% Block lookup
    function block = findBlockByName(parent,targetName,searchDepth)
        blocks = find_system(parent,'SearchDepth',searchDepth,...
            'LookUnderMasks','all','FollowLinks','on','Type','Block');
        target = normalizeName(targetName);
        block = '';
        for ii = 1:numel(blocks)
            current = get_param(blocks{ii},'Name');
            if strcmpi(normalizeName(current),target)
                block = blocks{ii};
                return;
            end
        end
        error('Could not find block "%s" inside "%s".',targetName,parent);
    end
    function value = normalizeName(value)
        value = regexprep(value,'\s+',' ');
        value = strtrim(value);
    end
end

%% Local helper functions
function tf = waitForStatus(mdl,target,timeoutSeconds)
t0 = tic;
tf = false;
while toc(t0) < timeoutSeconds
    if strcmp(get_param(mdl,'SimulationStatus'),target)
        tf = true;
        return;
    end
    drawnow;
    pause(0.02);
end
end
function [xs,ys] = springShape(x1,x2,y0,nCoils,amp)
L = x2-x1;
if L <= 0.10
    xs = [x1 x2];
    ys = [y0 y0];
    return;
end
lead = min(0.28,max(0.08,0.08*L));
xa = x1+lead;
xb = x2-lead;
if xb <= xa
    xs = [x1 x2];
    ys = [y0 y0];
    return;
end
nHalf = 2*nCoils;
xCoil = linspace(xa,xb,nHalf+1);
yCoil = y0 + amp*((-1).^(0:nHalf));
yCoil(1) = y0;
yCoil(end) = y0;
xs = [x1 xa xCoil(2:end-1) xb x2];
ys = [y0 y0 yCoil(2:end-1) y0 y0];
end
