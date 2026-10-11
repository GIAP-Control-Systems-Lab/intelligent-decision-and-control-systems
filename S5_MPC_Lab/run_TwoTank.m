% =========================================================================
% MaIA_SDCI - Semana 5: Model Predictive Control
% Sistemas de Decision y Control Inteligente
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
% Interactive Model Predictive Control laboratory for a two coupled-tank
% Simscape system.
%
% The manipulated variable is the total inlet volumetric flow q_in.
% The measured outputs are the liquid levels h1 and h2.
%
% The graphical interface allows the student to modify references, MPC
% horizons, tuning weights, constraints and simulation pacing while the
% simulation is running.
%
% The MPC plot shows past measured behavior together with the current
% receding-horizon predictions and optimal future control sequence.
% =========================================================================
function run_TwoTank

%% Project
mdl = 'S5_MPC_Lab';
projectFolder = fileparts(mfilename('fullpath'));
mdlFile = fullfile(projectFolder,[mdl '.slx']);
cacheFolder = fullfile(projectFolder,'cache');
controllerFile = fullfile(projectFolder,'MPC_TwoTank_Controller.mat');
if ~isfile(mdlFile)
    error('Cannot find %s in the same folder as run_TwoTank.m.',[mdl '.slx']);
end
if ~isfolder(cacheFolder)
    mkdir(cacheFolder);
end
try
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
mpcSubsystem = findBlockByName(mdl,'Model Predictive Control',1);
plantSubsystem = findBlockByName(mdl,'Two-Tank Plant',1);
h1RefBlock = findBlockByName(mdl,'Tank 1 Reference',1);
h2RefBlock = findBlockByName(mdl,'Tank 2 Reference',1);
mpcBlock = findBlockByNameOptional(mpcSubsystem,'MPC Controller',2);
firstOrderHoldBlock = findBlockByNameOptional(mpcSubsystem,'First Order Hold',2);
plantScopeBlock = findBlockByNameOptional(plantSubsystem,'h',2);
predictionHorizonBlock = findBlockByNameOptional(mpcSubsystem,'Prediction Horizon',2);
controlHorizonBlock = findBlockByNameOptional(mpcSubsystem,'Control Horizon',2);
outputWeightsBlock = findBlockByNameOptional(mpcSubsystem,'Output Weights',2);
mvWeightBlock = findBlockByNameOptional(mpcSubsystem,'MV Weight',2);
mvRateWeightBlock = findBlockByNameOptional(mpcSubsystem,'MV Rate Weight',2);
minimumOutputBlock = findBlockByNameOptional(mpcSubsystem,'Minimum Output',2);
maximumOutputBlock = findBlockByNameOptional(mpcSubsystem,'Maximum Output',2);
minimumFlowBlock = findBlockByNameOptional(mpcSubsystem,'Minimum Flow',2);
maximumFlowBlock = findBlockByNameOptional(mpcSubsystem,'Maximum Flow',2);

%% MPC controller
mpcController = loadMPCController(controllerFile);
assignin('base','mpcController',mpcController);

%% Fluid and environment
p.T_water = 293.15;
p.p_env = 0.736842;
p.g = 9.7754;

%% Tank geometry
p.A_tank = 15.518;
p.h_max = 30;
p.V_max = p.A_tank*p.h_max;

%% Hydraulic connections
p.d_orifice = 0.48;                  % cm
p.A_12  = pi*(p.d_orifice/2)^2;      % cm^2, Tank 1 -> Tank 2
p.A_out = pi*(p.d_orifice/2)^2;      % cm^2, Tank 2 -> reservoir

%% Tank ports
p.h_ports_T1 = [p.h_max 0];
p.A_ports_T1 = [p.A_tank p.A_tank];
p.h_ports_T2 = [0 p.h_max 0];
p.A_ports_T2 = [p.A_tank p.A_tank p.A_tank];

%% Initial conditions
p.h1_0 = 0;
p.h2_0 = 0;

%% Inlet flow distribution
p.gamma = 0.5;

%% References
p.h1_ref = 15;
p.h2_ref = 10;
p.refMin = 0;
p.refMax = p.h_max;

%% MPC parameters
p.mpcTs = 0.5;
p.predictionHorizon = 30;
p.maxPredictionHorizon = 80;
p.controlHorizon = 5;
p.wy1 = 0;
p.wy2 = 1;
p.wu = 0;
p.wdu = 0.20;
p.h1_min = 0;
p.h2_min = 0;
p.h1_max = 30;
p.h2_max = 30;
p.q_min = 0;
p.q_max = 40;

%% Open-loop test input
p.q_in_initial = 0;
p.Cd = 0.64;
p.q_in_step = p.Cd*p.A_out*sqrt(2*(p.g*100)*p.h2_ref);
p.t_step = 0;

%% Simulation
p.t_stop = 200;
% 0.05 s is conservative relative to the 0.5 s MPC sample time and is
% substantially faster than the previous 0.01 s maximum step.
p.maxStep = 0.05;
p.pacingEnabled = true;
p.pacingRate = 1;
p.guiFramePeriod = 1/20;
p.plotWindow = 60;
p.plotLead = 5;
p.maxPlotPoints = 20000;

%% Runtime state
state.monitor = [];
state.running = false;
% True between the start command and confirmation that Simulink is running.
% Prevent the GUI monitor from misinterpreting transient 'stopped' status
% during compilation/initialization as the end of the simulation.
state.starting = false;
% Fast (unpaced) simulations may finish before the GUI timer runs.
% Keep the session alive until SDI has flushed the recorded signals.
state.finalizeClock = [];
state.lastSDIAttempt = [];
state.sdiRecovered = false;
state.previousSDIRunID = NaN;
state.paused = false;
state.lastFrameTime = -inf;
state.lastSimulationTime = 0;
state.lastSampleTime = -inf;
state.liveTimerStart = [];
state.liveWarningShown = false;
state.h1 = p.h1_0;
state.h2 = p.h2_0;
state.q = 0;
state.cost = NaN;
state.qpStatus = NaN;
state.yseq = [];
state.mvseq = [];
state.t = [];
state.h1History = [];
state.h2History = [];
state.qHistory = [];
state.h1RefHistory = [];
state.h2RefHistory = [];
state.currentH1Ref = p.h1_ref;
state.currentH2Ref = p.h2_ref;
state.live = initializeLiveState();
ui = struct();
publishBaseVariables();
configureModel();
applyReferenceValues();
applyAllLiveMPCValues();
if ~isempty(mpcBlock)
    set_param(mpcBlock,'mpcobj','mpcController');
end

%% Animation geometry
% Physical presentation: upper tank -> lower tank -> reservoir -> pump.
% IMPORTANT: current Simscape plant uses gamma=0.5 and therefore also
% pumps 50% of q_in directly to Tank 2. The optional upper-tank drain tap
% is drawn CLOSED as a hardware feature; it is not a simulated flow path.
geo.tank1Bottom = 22.4;
geo.tank2Bottom = 5.1;
geo.tankHeight = 12.8;
geo.tankWidth = 1.72;
geo.tank1X = 8.40;
geo.tank2X = 8.40;
geo.scale = geo.tankHeight/p.h_max;
geo.splitX = 3.00;
geo.resX = 16.00;

%% GUI
oldFig = findall(groot,'Type','figure','Tag','TWO_TANK_MPC_INTERACTIVE_LAB');
if ~isempty(oldFig)
    delete(oldFig);
end
fig = uifigure(...
    'Name','Two Coupled Tanks | Interactive MPC Laboratory',...
    'Tag','TWO_TANK_MPC_INTERACTIVE_LAB',...
    'WindowState','maximized',...
    'Color',[0.97 0.97 0.97],...
    'CloseRequestFcn',@closeApp);
main = uigridlayout(fig,[2 2]);
main.ColumnWidth = {500,'1x'};
main.RowHeight = {'0.82x','1.18x'};
main.Padding = [8 8 8 8];
main.RowSpacing = 8;
main.ColumnSpacing = 10;

%% Scrollable control area
controlScroll = uipanel(main,...
    'Title','Controls',...
    'FontWeight','bold',...
    'Scrollable','on');
controlScroll.Layout.Row = [1 2];
controlScroll.Layout.Column = 1;
controlContent = uipanel(controlScroll,...
    'BorderType','none',...
    'Units','pixels',...
    'Position',[0 0 470 1330]);
left = uigridlayout(controlContent,[6 1]);
left.RowHeight = {150,325,235,225,275,40};
left.Padding = [5 5 5 5];
left.RowSpacing = 5;

%% References
refPanel = uipanel(left,'Title','Tank references — LIVE','FontWeight','bold');
refPanel.Layout.Row = 1;
refGrid = uigridlayout(refPanel,[2 3]);
refGrid.ColumnWidth = {160,'1x',80};
refGrid.RowHeight = {50,50};
refGrid.Padding = [8 5 8 5];
refGrid.RowSpacing = 4;
refGrid.ColumnSpacing = 10;
uilabel(refGrid,...
    'Text','Tank 1 reference [cm]',...
    'VerticalAlignment','center');
ui.h1RefSlider = uislider(refGrid,...
    'Limits',[p.refMin p.refMax],...
    'Value',p.h1_ref,...
    'MajorTicks',[0 5 10 15 20 25 30],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)referenceChanging(1,e.Value),...
    'ValueChangedFcn',@(s,e)referenceChanged(1,s.Value));
ui.h1RefEdit = uieditfield(refGrid,'numeric',...
    'Limits',[p.refMin p.refMax],...
    'Value',p.h1_ref,...
    'ValueDisplayFormat','%.2f',...
    'ValueChangedFcn',@(s,e)referenceEditChanged(1,s.Value));
uilabel(refGrid,...
    'Text','Tank 2 reference [cm]',...
    'VerticalAlignment','center');
ui.h2RefSlider = uislider(refGrid,...
    'Limits',[p.refMin p.refMax],...
    'Value',p.h2_ref,...
    'MajorTicks',[0 5 10 15 20 25 30],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)referenceChanging(2,e.Value),...
    'ValueChangedFcn',@(s,e)referenceChanged(2,s.Value));
ui.h2RefEdit = uieditfield(refGrid,'numeric',...
    'Limits',[p.refMin p.refMax],...
    'Value',p.h2_ref,...
    'ValueDisplayFormat','%.2f',...
    'ValueChangedFcn',@(s,e)referenceEditChanged(2,s.Value));

%% MPC tuning
tuningPanel = uipanel(left,'Title','MPC tuning — applies on Run / Restart','FontWeight','bold');
tuningPanel.Layout.Row = 2;
tg = uigridlayout(tuningPanel,[6 3]);
tg.ColumnWidth = {160,'1x',80};
tg.RowHeight = {43,43,43,43,43,43};
tg.Padding = [8 5 8 5];
tg.RowSpacing = 4;
tg.ColumnSpacing = 10;
uilabel(tg,'Text','Prediction horizon P');
ui.pSlider = uislider(tg,...
    'Limits',[2 p.maxPredictionHorizon],...
    'Value',p.predictionHorizon,...
    'MajorTicks',[2 10 20 30 40 60 80],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)horizonChanging('P',e.Value),...
    'ValueChangedFcn',@(s,e)horizonChanged('P',s.Value));
ui.pEdit = uieditfield(tg,'numeric',...
    'Limits',[2 p.maxPredictionHorizon],...
    'Value',p.predictionHorizon,...
    'RoundFractionalValues','on',...
    'ValueChangedFcn',@(s,e)horizonEditChanged('P',s.Value));
uilabel(tg,'Text','Control horizon M');
ui.mSlider = uislider(tg,...
    'Limits',[1 p.maxPredictionHorizon],...
    'Value',p.controlHorizon,...
    'MajorTicks',[1 10 20 30 40 60 80],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)horizonChanging('M',e.Value),...
    'ValueChangedFcn',@(s,e)horizonChanged('M',s.Value));
ui.mEdit = uieditfield(tg,'numeric',...
    'Limits',[1 p.maxPredictionHorizon],...
    'Value',p.controlHorizon,...
    'RoundFractionalValues','on',...
    'ValueChangedFcn',@(s,e)horizonEditChanged('M',s.Value));
uilabel(tg,'Text','Tank 1 tracking weight Wy1');
ui.wy1Slider = uislider(tg,...
    'Limits',[0 5],...
    'Value',p.wy1,...
    'MajorTicks',[0 1 2 3 4 5],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)weightSliderChanging('Wy1',e.Value),...
    'ValueChangedFcn',@(s,e)weightSliderChanged('Wy1',s.Value));
ui.wy1Edit = uieditfield(tg,'numeric',...
    'Limits',[0 Inf],...
    'Value',p.wy1,...
    'ValueDisplayFormat','%.3g',...
    'ValueChangedFcn',@(s,e)weightEditChanged('Wy1',s.Value));
uilabel(tg,'Text','Tank 2 tracking weight Wy2');
ui.wy2Slider = uislider(tg,...
    'Limits',[0 5],...
    'Value',p.wy2,...
    'MajorTicks',[0 1 2 3 4 5],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)weightSliderChanging('Wy2',e.Value),...
    'ValueChangedFcn',@(s,e)weightSliderChanged('Wy2',s.Value));
ui.wy2Edit = uieditfield(tg,'numeric',...
    'Limits',[0 Inf],...
    'Value',p.wy2,...
    'ValueDisplayFormat','%.3g',...
    'ValueChangedFcn',@(s,e)weightEditChanged('Wy2',s.Value));
uilabel(tg,'Text','Flow magnitude weight Wu');
ui.wuSlider = uislider(tg,...
    'Limits',[0 2],...
    'Value',p.wu,...
    'MajorTicks',[0 0.5 1 1.5 2],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)weightSliderChanging('Wu',e.Value),...
    'ValueChangedFcn',@(s,e)weightSliderChanged('Wu',s.Value));
ui.wuEdit = uieditfield(tg,'numeric',...
    'Limits',[0 Inf],...
    'Value',p.wu,...
    'ValueDisplayFormat','%.3g',...
    'ValueChangedFcn',@(s,e)weightEditChanged('Wu',s.Value));
uilabel(tg,'Text','Flow-rate weight Wdu');
ui.wduSlider = uislider(tg,...
    'Limits',[0 2],...
    'Value',p.wdu,...
    'MajorTicks',[0 0.5 1 1.5 2],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)weightSliderChanging('Wdu',e.Value),...
    'ValueChangedFcn',@(s,e)weightSliderChanged('Wdu',s.Value));
ui.wduEdit = uieditfield(tg,'numeric',...
    'Limits',[0 Inf],...
    'Value',p.wdu,...
    'ValueDisplayFormat','%.3g',...
    'ValueChangedFcn',@(s,e)weightEditChanged('Wdu',s.Value));

%% Constraints
constraintPanel = uipanel(left,'Title','Constraints — applies on Run / Restart','FontWeight','bold');
constraintPanel.Layout.Row = 3;
cg = uigridlayout(constraintPanel,[4 3]);
cg.ColumnWidth = {160,'1x',80};
cg.RowHeight = {43,43,43,43};
cg.Padding = [8 5 8 5];
cg.RowSpacing = 4;
cg.ColumnSpacing = 10;
uilabel(cg,'Text','Minimum q_in [cm^3/s]');
ui.qMinSlider = uislider(cg,...
    'Limits',[0 40],...
    'Value',p.q_min,...
    'MajorTicks',[0 10 20 30 40],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)constraintSliderChanging('qMin',e.Value),...
    'ValueChangedFcn',@(s,e)constraintSliderChanged('qMin',s.Value));
ui.qMinEdit = uieditfield(cg,'numeric',...
    'Value',p.q_min,...
    'ValueDisplayFormat','%.2f',...
    'ValueChangedFcn',@(s,e)constraintEditChanged('qMin',s.Value));
uilabel(cg,'Text','Maximum q_in [cm^3/s]');
ui.qMaxSlider = uislider(cg,...
    'Limits',[1 60],...
    'Value',p.q_max,...
    'MajorTicks',[1 10 20 30 40 50 60],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)constraintSliderChanging('qMax',e.Value),...
    'ValueChangedFcn',@(s,e)constraintSliderChanged('qMax',s.Value));
ui.qMaxEdit = uieditfield(cg,'numeric',...
    'Value',p.q_max,...
    'ValueDisplayFormat','%.2f',...
    'ValueChangedFcn',@(s,e)constraintEditChanged('qMax',s.Value));
uilabel(cg,'Text','Maximum Tank 1 level [cm]');
ui.h1MaxSlider = uislider(cg,...
    'Limits',[1 p.h_max],...
    'Value',p.h1_max,...
    'MajorTicks',[1 5 10 15 20 25 30],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)constraintSliderChanging('h1Max',e.Value),...
    'ValueChangedFcn',@(s,e)constraintSliderChanged('h1Max',s.Value));
ui.h1MaxEdit = uieditfield(cg,'numeric',...
    'Limits',[1 p.h_max],...
    'Value',p.h1_max,...
    'ValueDisplayFormat','%.2f',...
    'ValueChangedFcn',@(s,e)constraintEditChanged('h1Max',s.Value));
uilabel(cg,'Text','Maximum Tank 2 level [cm]');
ui.h2MaxSlider = uislider(cg,...
    'Limits',[1 p.h_max],...
    'Value',p.h2_max,...
    'MajorTicks',[1 5 10 15 20 25 30],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)constraintSliderChanging('h2Max',e.Value),...
    'ValueChangedFcn',@(s,e)constraintSliderChanged('h2Max',s.Value));
ui.h2MaxEdit = uieditfield(cg,'numeric',...
    'Limits',[1 p.h_max],...
    'Value',p.h2_max,...
    'ValueDisplayFormat','%.2f',...
    'ValueChangedFcn',@(s,e)constraintEditChanged('h2Max',s.Value));

%% Live information
infoPanel = uipanel(left,'Title','Live MPC information','FontWeight','bold');
infoPanel.Layout.Row = 4;
ig = uigridlayout(infoPanel,[8 2]);
ig.ColumnWidth = {'1x',110};
ig.RowHeight = {21,21,21,21,21,21,21,21};
ig.Padding = [8 4 8 4];
ig.RowSpacing = 1;
ig.ColumnSpacing = 10;
uilabel(ig,'Text','Tank 1 level [cm]');
ui.h1Value = uilabel(ig,...
    'Text','0.000',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');
uilabel(ig,'Text','Tank 2 level [cm]');
ui.h2Value = uilabel(ig,...
    'Text','0.000',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');
uilabel(ig,'Text','Current q_in [cm^3/s]');
ui.qValue = uilabel(ig,...
    'Text','0.000',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');
uilabel(ig,'Text','Optimal cost');
ui.costValue = uilabel(ig,...
    'Text','—',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');
uilabel(ig,'Text','QP status');
ui.qpValue = uilabel(ig,...
    'Text','—',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');
% Competition metrics: absolute final (or live) tracking errors in cm.
% E_total = |h1 - h1_ref| + |h2 - h2_ref|.
uilabel(ig,'Text','Tank 1 absolute error [cm]');
ui.h1ErrorValue = uilabel(ig,...
    'Text','—',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');
uilabel(ig,'Text','Tank 2 absolute error [cm]');
ui.h2ErrorValue = uilabel(ig,...
    'Text','—',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');
uilabel(ig,'Text','Total absolute error [cm]','FontWeight','bold');
ui.totalErrorValue = uilabel(ig,...
    'Text','—',...
    'FontWeight','bold',...
    'HorizontalAlignment','right');

%% Simulation
simulationPanel = uipanel(left,'Title','Simulation','FontWeight','bold');
simulationPanel.Layout.Row = 5;
sg = uigridlayout(simulationPanel,[5 1]);
sg.RowHeight = {32,32,34,58,43};
sg.Padding = [6 5 6 5];
sg.RowSpacing = 5;
buttons1 = uigridlayout(sg,[1 3]);
buttons1.Layout.Row = 1;
buttons1.ColumnWidth = {'1x','1x','1x'};
buttons1.Padding = [0 0 0 0];
buttons1.ColumnSpacing = 7;
ui.runButton = uibutton(buttons1,...
    'Text','Run / Restart',...
    'FontWeight','bold',...
    'ButtonPushedFcn',@runSimulation);
ui.pauseButton = uibutton(buttons1,...
    'Text','Pause',...
    'Enable','off',...
    'ButtonPushedFcn',@pauseResumeSimulation);
ui.stopButton = uibutton(buttons1,...
    'Text','Stop',...
    'Enable','off',...
    'ButtonPushedFcn',@stopSimulation);
buttons2 = uigridlayout(sg,[1 3]);
buttons2.Layout.Row = 2;
buttons2.ColumnWidth = {'1x','1x','1x'};
buttons2.Padding = [0 0 0 0];
buttons2.ColumnSpacing = 7;
ui.openButton = uibutton(buttons2,...
    'Text','Open Simulink',...
    'ButtonPushedFcn',@openModel);
ui.defaultsButton = uibutton(buttons2,...
    'Text','Defaults',...
    'ButtonPushedFcn',@restoreDefaults);
ui.clearButton = uibutton(buttons2,...
    'Text','Clear Plots',...
    'ButtonPushedFcn',@clearHistory);
pacingEnableGrid = uigridlayout(sg,[1 2]);
pacingEnableGrid.Layout.Row = 3;
pacingEnableGrid.ColumnWidth = {110,'1x'};
pacingEnableGrid.Padding = [0 0 0 0];
ui.pacingEnabled = uicheckbox(pacingEnableGrid,...
    'Text','Enable pacing',...
    'Value',p.pacingEnabled,...
    'ValueChangedFcn',@(s,e)pacingChanged());
uilabel(pacingEnableGrid,...
    'Text','Simulation speed — LIVE',...
    'FontWeight','bold',...
    'HorizontalAlignment','center');
pacingGrid = uigridlayout(sg,[1 3]);
pacingGrid.Layout.Row = 4;
pacingGrid.ColumnWidth = {70,'1x',80};
pacingGrid.Padding = [0 4 0 0];
pacingGrid.ColumnSpacing = 10;
uilabel(pacingGrid,...
    'Text','Speed',...
    'VerticalAlignment','center');
ui.pacingSlider = uislider(pacingGrid,...
    'Limits',[0.1 5],...
    'Value',p.pacingRate,...
    'MajorTicks',[0.1 0.5 1 2 3 4 5],...
    'MinorTicks',[],...
    'FontSize',10,...
    'ValueChangingFcn',@(s,e)pacingSliderChanging(e.Value),...
    'ValueChangedFcn',@(s,e)pacingSliderChanged(s.Value));
ui.pacingEdit = uieditfield(pacingGrid,'numeric',...
    'Limits',[0.1 5],...
    'Value',p.pacingRate,...
    'ValueDisplayFormat','%.2f',...
    'ValueChangedFcn',@(s,e)pacingEditChanged(s.Value));
% Stop time is independent of the pacing rate and takes effect on Restart.
stopGrid = uigridlayout(sg,[1 2]);
stopGrid.Layout.Row = 5;
stopGrid.ColumnWidth = {'1x',110};
stopGrid.Padding = [1 0 1 0];
stopGrid.ColumnSpacing = 8;
uilabel(stopGrid,...
    'Text','Stop time [s] — applies on Run / Restart',...
    'VerticalAlignment','center');
ui.stopTimeEdit = uieditfield(stopGrid,'numeric',...
    'Limits',[0.5 Inf],...
    'Value',p.t_stop,...
    'ValueDisplayFormat','%.1f',...
    'ValueChangedFcn',@(src,event)stopTimeChanged(src.Value));

%% Status
statusPanel = uipanel(left,'BorderType','none');
statusPanel.Layout.Row = 6;
statusGrid = uigridlayout(statusPanel,[1 1]);
statusGrid.Padding = [3 1 3 1];
ui.status = uilabel(statusGrid,...
    'Text','Ready.',...
    'HorizontalAlignment','center',...
    'FontWeight','bold',...
    'FontSize',11,...
    'WordWrap','on');

%% Tank animation
animationPanel = uipanel(main,...
    'Title','Live two-tank system',...
    'FontWeight','bold');
animationPanel.Layout.Row = 1;
animationPanel.Layout.Column = 2;
ag = uigridlayout(animationPanel,[1 1]);
ag.Padding = [8 8 8 8];
ui.axTank = uiaxes(ag);
ui.axTank.Toolbar.Visible = 'off';
ui.axTank.Interactions = [];
buildTankView();

%% MPC signals
plotPanel = uipanel(main,...
    'Title','MPC signals — past behavior and receding prediction horizon',...
    'FontWeight','bold');
plotPanel.Layout.Row = 2;
plotPanel.Layout.Column = 2;
pg = uigridlayout(plotPanel,[1 1]);
pg.Padding = [8 8 8 8];
ui.axMPC = uiaxes(pg);
ui.axMPC.Toolbar.Visible = 'off';
prepareMPCPlot();
% The Simulink model streams live packets to TwoTank_LiveDataCallback.
% Store a nested receiver function handle so the callback can update this
% specific GUI instance without using execution listeners.
setappdata(groot,'S5_MPC_LiveReceiver',@receiveLivePacket);

%% Simulation monitor
state.monitor = timer(...
    'ExecutionMode','fixedSpacing',...
    'Period',p.guiFramePeriod,...
    'BusyMode','drop',...
    'TimerFcn',@monitorSimulation);
start(state.monitor);
updateControllerAvailabilityStatus();

%% References
    function referenceChanging(index,value)
        setReference(index,value);
    end
    function referenceChanged(index,value)
        setReference(index,value);
    end
    function referenceEditChanged(index,value)
        setReference(index,value);
    end
    function setReference(index,value)
        value = min(max(value,p.refMin),p.refMax);
        if index == 1
            ui.h1RefSlider.Value = value;
            ui.h1RefEdit.Value = value;
            state.currentH1Ref = value;
            assignin('base','h1_ref',value);
            set_param(h1RefBlock,'Value',num2str(value,16));
        else
            ui.h2RefSlider.Value = value;
            ui.h2RefEdit.Value = value;
            state.currentH2Ref = value;
            assignin('base','h2_ref',value);
            set_param(h2RefBlock,'Value',num2str(value,16));
        end
        updateTankView();
        updateMPCPlot();
        % Keep the displayed errors consistent with live reference changes.
        updateLiveValues();
    end

%% Horizons
    function horizonChanging(name,value)
        applyHorizon(name,value);
    end
    function horizonChanged(name,value)
        applyHorizon(name,value);
    end
    function horizonEditChanged(name,value)
        applyHorizon(name,value);
    end
    function applyHorizon(name,value)
        value = round(value);
        if strcmp(name,'P')
            value = min(max(2,value),p.maxPredictionHorizon);
            ui.pSlider.Value = value;
            ui.pEdit.Value = value;
            if ui.mEdit.Value > value
                ui.mEdit.Value = value;
                ui.mSlider.Value = value;
            end
        else
            value = min(max(1,value),round(ui.pEdit.Value));
            ui.mSlider.Value = value;
            ui.mEdit.Value = value;
        end
        P = round(ui.pEdit.Value);
        M = min(round(ui.mEdit.Value),P);
        ui.mEdit.Value = M;
        ui.mSlider.Value = M;
        assignin('base','mpc_P',P);
        assignin('base','mpc_M',M);
        syncMPCControllerFromUI();
        updateMPCPlot();
        setStatus(sprintf('MPC horizons updated: P = %d | M = %d. Applied on Run / Restart.',P,M));
    end

%% Weights
    function weightSliderChanging(name,value)
        applyWeight(name,value);
    end
    function weightSliderChanged(name,value)
        applyWeight(name,value);
    end
    function weightEditChanged(name,value)
        applyWeight(name,value);
    end
    function applyWeight(name,value)
        value = max(0,value);
        switch name
            case 'Wy1'
                ui.wy1Edit.Value = value;
                ui.wy1Slider.Value = min(value,ui.wy1Slider.Limits(2));
            case 'Wy2'
                ui.wy2Edit.Value = value;
                ui.wy2Slider.Value = min(value,ui.wy2Slider.Limits(2));
            case 'Wu'
                ui.wuEdit.Value = value;
                ui.wuSlider.Value = min(value,ui.wuSlider.Limits(2));
            case 'Wdu'
                ui.wduEdit.Value = value;
                ui.wduSlider.Value = min(value,ui.wduSlider.Limits(2));
        end
        applyWeightValues();
    end
    function applyWeightValues()
        Wy = [ui.wy1Edit.Value ui.wy2Edit.Value];
        Wu = ui.wuEdit.Value;
        Wdu = ui.wduEdit.Value;
        assignin('base','mpc_Wy',Wy);
        assignin('base','mpc_Wu',Wu);
        assignin('base','mpc_Wdu',Wdu);
        syncMPCControllerFromUI();
        setStatus(sprintf('MPC weights updated: Wy1 %.2f | Wy2 %.2f | Wu %.2f | Wdu %.2f. Applied on Run / Restart.',Wy(1),Wy(2),Wu,Wdu));
    end

%% Constraints
    function constraintSliderChanging(name,value)
        applyConstraint(name,value);
    end
    function constraintSliderChanged(name,value)
        applyConstraint(name,value);
    end
    function constraintEditChanged(name,value)
        applyConstraint(name,value);
    end
    function applyConstraint(name,value)
        switch name
            case 'qMin'
                ui.qMinEdit.Value = value;
                ui.qMinSlider.Value = min(max(value,...
                    ui.qMinSlider.Limits(1)),ui.qMinSlider.Limits(2));
            case 'qMax'
                ui.qMaxEdit.Value = value;
                ui.qMaxSlider.Value = min(max(value,...
                    ui.qMaxSlider.Limits(1)),ui.qMaxSlider.Limits(2));
            case 'h1Max'
                value = min(max(1,value),p.h_max);
                ui.h1MaxEdit.Value = value;
                ui.h1MaxSlider.Value = value;
            case 'h2Max'
                value = min(max(1,value),p.h_max);
                ui.h2MaxEdit.Value = value;
                ui.h2MaxSlider.Value = value;
        end
        if ui.qMinEdit.Value >= ui.qMaxEdit.Value
            if strcmp(name,'qMin')
                ui.qMaxEdit.Value = ui.qMinEdit.Value+0.1;
                ui.qMaxSlider.Value = min(...
                    ui.qMaxEdit.Value,ui.qMaxSlider.Limits(2));
            else
                ui.qMinEdit.Value = ui.qMaxEdit.Value-0.1;
                ui.qMinSlider.Value = max(...
                    ui.qMinEdit.Value,ui.qMinSlider.Limits(1));
            end
        end
        applyConstraintValues();
    end
    function applyConstraintValues()
        qMin = ui.qMinEdit.Value;
        qMax = ui.qMaxEdit.Value;
        yMin = [p.h1_min p.h2_min];
        yMax = [ui.h1MaxEdit.Value ui.h2MaxEdit.Value];
        assignin('base','mpc_ymin',yMin);
        assignin('base','mpc_ymax',yMax);
        assignin('base','mpc_umin',qMin);
        assignin('base','mpc_umax',qMax);
        syncMPCControllerFromUI();
        updateMPCPlot();
        updateTankView();
        setStatus('MPC constraints updated. Applied on Run / Restart.');
    end

%% Pacing
    function pacingSliderChanging(value)
        ui.pacingEdit.Value = value;
        applyPacing();
    end
    function pacingSliderChanged(value)
        ui.pacingSlider.Value = value;
        ui.pacingEdit.Value = value;
        applyPacing();
    end
    function pacingEditChanged(value)
        ui.pacingSlider.Value = value;
        applyPacing();
    end
    function pacingChanged()
        applyPacing();
    end
    function applyPacing()
        enabled = ui.pacingEnabled.Value;
        rate = ui.pacingEdit.Value;
        try
            if enabled
                set_param(mdl,...
                    'EnablePacing','on',...
                    'PacingRate',num2str(rate,16));
                ui.pacingSlider.Enable = 'on';
                ui.pacingEdit.Enable = 'on';
                setStatus(sprintf('Pacing %.2fx',rate));
            else
                set_param(mdl,'EnablePacing','off');
                ui.pacingSlider.Enable = 'off';
                ui.pacingEdit.Enable = 'off';
                setStatus('Pacing disabled.');
            end
        catch ME
            warning('Could not update pacing: %s',ME.message);
        end
    end

%% Stop time
    function stopTimeChanged(value)
        if ~isfinite(value) || value < 0.5
            ui.stopTimeEdit.Value = p.t_stop;
            setStatus('Stop time must be at least 0.5 s.');
            return;
        end
        setStatus(sprintf('Stop time = %.1f s. Applies on Run / Restart.',value));
    end

%% Simulation
    function runSimulation(~,~)
        try
            stopIfNeeded();
            refreshControllerBlocks();
            validateControllerInterface();
            validateInputs();
            publishBaseVariables();
            configureModel();
            configureSignalLogging();
            applyReferenceValues();
            applyAllLiveMPCValues();
            clearHistory();
            resetLiveState();
            state.paused = false;
            state.lastFrameTime = -inf;
            state.lastSimulationTime = 0;
            state.lastSampleTime = -inf;
            state.liveWarningShown = false;
            state.liveTimerStart = tic;
            state.finalizeClock = [];
            state.lastSDIAttempt = [];
            state.sdiRecovered = false;
            % Identifies the new SDI run, preventing stale results on Restart.
            state.previousSDIRunID = currentSDIRunID();
            ui.pauseButton.Enable = 'on';
            ui.stopButton.Enable = 'on';
            ui.pauseButton.Text = 'Pause';
            setStatus('Compiling...');
            drawnow;
            set_param(mdl,'SimulationCommand','update');
            state.starting = true;
            state.running = true;
            set_param(mdl,'SimulationCommand','start');
            % Without pacing the simulation can reach StopTime before
            % MATLAB returns from the start command. Stopped is valid here.
            status = get_param(mdl,'SimulationStatus');
            if ~any(strcmp(status,{'running','stopped','paused'}))
                tStart = tic;
                while toc(tStart) < 15
                    drawnow limitrate;
                    pause(0.02);
                    status = get_param(mdl,'SimulationStatus');
                    if any(strcmp(status,{'running','stopped','paused'}))
                        break;
                    end
                end
            end
            state.starting = false;
            if strcmp(status,'stopped')
                % Do not mistake a fast, completed run for a failed start.
                finalizeCompletedRun();
                return;
            elseif ~any(strcmp(status,{'running','paused'}))
                error('The model did not start. Check the Simulink Diagnostic Viewer.');
            end
            state.running = true;
            ui.pauseButton.Enable = 'on';
            ui.stopButton.Enable = 'on';
            if strcmp(status,'paused')
                state.paused = true;
                ui.pauseButton.Text = 'Continue';
                setStatus('Simulation paused.');
            else
                setStatus('Running. Waiting for live signal packets...');
            end
        catch ME
            try
                if bdIsLoaded(mdl) && ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
                    set_param(mdl,'SimulationCommand','stop');
                end
            catch
            end
            state.starting = false;
            state.running = false;
            state.paused = false;
            ui.pauseButton.Enable = 'off';
            ui.stopButton.Enable = 'off';
            setStatus('Error.');
            warning('%s',getReport(ME,'extended','hyperlinks','off'));
            uialert(fig,ME.message,'Simulation error');
        end
    end
    function pauseResumeSimulation(~,~)
        if ~bdIsLoaded(mdl)
            return;
        end
        status = get_param(mdl,'SimulationStatus');
        if strcmp(status,'running')
            set_param(mdl,'SimulationCommand','pause');
            state.paused = true;
            ui.pauseButton.Text = 'Continue';
            setStatus(sprintf(...
                'Paused | t = %.2f s',state.lastSimulationTime));
        elseif strcmp(status,'paused')
            set_param(mdl,'SimulationCommand','continue');
            state.paused = false;
            ui.pauseButton.Text = 'Pause';
            setStatus(sprintf(...
                'Running | t = %.2f s',state.lastSimulationTime));
        end
    end
    function stopSimulation(~,~)
        if bdIsLoaded(mdl) && ...
                ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
            set_param(mdl,'SimulationCommand','stop');
            waitForStatus(mdl,'stopped',5);
        end
        deleteListeners();
        state.starting = false;
        state.running = false;
        state.paused = false;
        ui.pauseButton.Text = 'Pause';
        ui.pauseButton.Enable = 'off';
        ui.stopButton.Enable = 'off';
        setStatus('Stopped.');
    end
    function openModel(~,~)
        open_system(mdl);
    end

%% Live simulation data
    function live = initializeLiveState()
        live = struct();
        live.hTime = zeros(0,1);
        live.hValue = zeros(0,2);
        live.qTime = zeros(0,1);
        live.qValue = zeros(0,1);
        live.cost = NaN;
        live.costTime = -inf;
        live.status = NaN;
        live.statusTime = -inf;
        live.mvseq = [];
        live.mvseqTime = -inf;
        live.yseq = [];
        live.yseqTime = -inf;
        live.packetCount = zeros(1,6);
    end
    function resetLiveState()
        state.live = initializeLiveState();
    end
    function receiveLivePacket(data,time,signalID)
        % signalID: 1=h=[h1 h2], 2=q_in, 3=cost,
        % 4=mv.seq, 5=y.seq, 6=qp.status.
        if ~(state.running || state.starting)
            return;
        end
        if ischar(signalID) || isstring(signalID)
            signalID = str2double(signalID);
        end
        if ~isnumeric(signalID) || ~isscalar(signalID) || ~isfinite(signalID)
            return;
        end
        signalID = round(double(signalID));
        if signalID < 1 || signalID > 6
            return;
        end
        try
            switch signalID
                case 1
                    [tt,vv] = normalizeVectorPacket(data,time,2);
                    if isempty(tt)
                        return;
                    end
                    keep = tt > latestTime(state.live.hTime)+1e-12;
                    tt = tt(keep);
                    vv = vv(keep,:);
                    if isempty(tt)
                        return;
                    end
                    state.live.hTime = [state.live.hTime;tt];
                    state.live.hValue = [state.live.hValue;vv];
                case 2
                    [tt,vv] = normalizeScalarPacket(data,time);
                    if isempty(tt)
                        return;
                    end
                    keep = tt > latestTime(state.live.qTime)+1e-12;
                    tt = tt(keep);
                    vv = vv(keep);
                    if isempty(tt)
                        return;
                    end
                    state.live.qTime = [state.live.qTime;tt];
                    state.live.qValue = [state.live.qValue;vv];
                case 3
                    [tt,vv] = normalizeScalarPacket(data,time);
                    if ~isempty(tt)
                        state.live.cost = vv(end);
                        state.live.costTime = tt(end);
                    end
                case 4
                    [frame,tLast] = latestMatrixFrame(data,time);
                    if ~isempty(frame)
                        state.live.mvseq = frame;
                        state.live.mvseqTime = tLast;
                    end
                case 5
                    [frame,tLast] = latestMatrixFrame(data,time);
                    if ~isempty(frame)
                        state.live.yseq = frame;
                        state.live.yseqTime = tLast;
                    end
                case 6
                    [tt,vv] = normalizeScalarPacket(data,time);
                    if ~isempty(tt)
                        state.live.status = vv(end);
                        state.live.statusTime = tt(end);
                    end
            end
            state.live.packetCount(signalID) = state.live.packetCount(signalID)+1;
        catch ME
            if state.running
                warning('Two-tank live packet %d skipped: %s',signalID,ME.message);
            end
        end
    end
    function [tt,vv] = normalizeScalarPacket(data,time)
        tt = double(time(:));
        vv = double(data(:));
        n = min(numel(tt),numel(vv));
        tt = tt(1:n);
        vv = vv(1:n);
        good = isfinite(tt) & isfinite(vv);
        tt = tt(good);
        vv = vv(good);
    end
    function [tt,vv] = normalizeVectorPacket(data,time,nChannels)
        tt = double(time(:));
        d = double(data);
        vv = zeros(0,nChannels);
        if isempty(tt) || isempty(d)
            tt = zeros(0,1);
            return;
        end
        nt = numel(tt);
        d = squeeze(d);
        if isvector(d)
            if nt == 1 && numel(d) >= nChannels
                vv = reshape(d(1:nChannels),1,nChannels);
            elseif numel(d) == nt*nChannels
                vv = reshape(d,nChannels,nt).';
            else
                tt = zeros(0,1);
                return;
            end
        elseif size(d,1) == nt && size(d,2) >= nChannels
            vv = d(:,1:nChannels);
        elseif size(d,2) == nt && size(d,1) >= nChannels
            vv = d(1:nChannels,:).';
        else
            flat = d(:);
            if numel(flat) == nt*nChannels
                vv = reshape(flat,nChannels,nt).';
            else
                tt = zeros(0,1);
                return;
            end
        end
        n = min(numel(tt),size(vv,1));
        tt = tt(1:n);
        vv = vv(1:n,:);
        good = isfinite(tt) & all(isfinite(vv),2);
        tt = tt(good);
        vv = vv(good,:);
    end
    function [frame,tLast] = latestMatrixFrame(data,time)
        frame = [];
        tLast = -inf;
        tt = double(time(:));
        if isempty(tt)
            return;
        end
        d = double(data);
        tLast = tt(end);
        if ndims(d) >= 3
            frame = squeeze(d(:,:,end));
        else
            frame = squeeze(d);
        end
        if isempty(frame) || ~any(isfinite(frame(:)))
            frame = [];
            return;
        end
        frame = double(frame);
    end
    function t = latestTime(x)
        if isempty(x)
            t = -inf;
        else
            t = x(end);
        end
    end
    function q = qAtTimes(tq)
        q = state.q*ones(size(tq));
        tt = state.live.qTime;
        vv = state.live.qValue;
        if isempty(tt)
            return;
        end
        [tt,ia] = unique(tt,'stable');
        vv = vv(ia);
        if numel(tt) == 1
            q(:) = vv(end);
            return;
        end
        q = interp1(tt,vv,tq,'previous','extrap');
    end
    function processLiveData()
        if isempty(state.live.hTime)
            return;
        end
        use = state.live.hTime > state.lastSampleTime+1e-10;
        tt = state.live.hTime(use);
        hh = state.live.hValue(use,:);
        if isempty(tt)
            return;
        end
        qq = qAtTimes(tt);
        state.t = [state.t tt(:).'];
        state.h1History = [state.h1History hh(:,1).'];
        state.h2History = [state.h2History hh(:,2).'];
        state.qHistory = [state.qHistory qq(:).'];
        state.h1RefHistory = [state.h1RefHistory repmat(state.currentH1Ref,1,numel(tt))];
        state.h2RefHistory = [state.h2RefHistory repmat(state.currentH2Ref,1,numel(tt))];
        state.lastSampleTime = tt(end);
        state.lastSimulationTime = tt(end);
        state.h1 = hh(end,1);
        state.h2 = hh(end,2);
        state.q = qq(end);
        if isfinite(state.live.cost)
            state.cost = state.live.cost;
        end
        if isfinite(state.live.status)
            state.qpStatus = state.live.status;
        end
        if ~isempty(state.live.mvseq)
            state.mvseq = state.live.mvseq;
        end
        if ~isempty(state.live.yseq)
            state.yseq = state.live.yseq;
        end
        trimHistory();
        trimLiveBuffers();
    end
    function trimHistory()
        if numel(state.t) <= p.maxPlotPoints
            return;
        end
        excess = numel(state.t)-p.maxPlotPoints;
        state.t(1:excess) = [];
        state.h1History(1:excess) = [];
        state.h2History(1:excess) = [];
        state.qHistory(1:excess) = [];
        state.h1RefHistory(1:excess) = [];
        state.h2RefHistory(1:excess) = [];
    end
    function trimLiveBuffers()
        keepFrom = max(0,state.lastSampleTime-2);
        if ~isempty(state.live.hTime)
            keep = state.live.hTime >= keepFrom;
            state.live.hTime = state.live.hTime(keep);
            state.live.hValue = state.live.hValue(keep,:);
        end
        if ~isempty(state.live.qTime)
            keep = state.live.qTime >= keepFrom;
            state.live.qTime = state.live.qTime(keep);
            state.live.qValue = state.live.qValue(keep);
        end
    end

%% History
    function appendHistory(t)
        if ~isempty(state.t) && t <= state.t(end)+1e-10
            return;
        end
        state.t(end+1) = t;
        state.h1History(end+1) = state.h1;
        state.h2History(end+1) = state.h2;
        state.qHistory(end+1) = state.q;
        state.h1RefHistory(end+1) = state.currentH1Ref;
        state.h2RefHistory(end+1) = state.currentH2Ref;
        if numel(state.t) > p.maxPlotPoints
            excess = numel(state.t)-p.maxPlotPoints;
            state.t(1:excess) = [];
            state.h1History(1:excess) = [];
            state.h2History(1:excess) = [];
            state.qHistory(1:excess) = [];
            state.h1RefHistory(1:excess) = [];
            state.h2RefHistory(1:excess) = [];
        end
    end
    function clearHistory(varargin)
        state.t = [];
        state.h1History = [];
        state.h2History = [];
        state.qHistory = [];
        state.h1RefHistory = [];
        state.h2RefHistory = [];
        state.yseq = [];
        state.mvseq = [];
        state.cost = NaN;
        state.qpStatus = NaN;
        if isfield(ui,'axMPC') && isvalid(ui.axMPC)
            prepareMPCPlot();
        end
        if isfield(ui,'costValue') && isvalid(ui.costValue)
            updateLiveValues();
        end
    end

%% MPC plot
    function prepareMPCPlot()
        ax = ui.axMPC;
        cla(ax,'reset');
        hold(ax,'on');
        grid(ax,'on');
        ax.Box = 'on';
        ax.GridAlpha = 0.16;
        ax.MinorGridAlpha = 0.08;
        xlabel(ax,'Time [s]','Interpreter','none');
        yyaxis(ax,'left');
        ylabel(ax,'Liquid level [cm]','Interpreter','none');
        ylim(ax,[0 p.h_max*1.08]);
        ui.predictionArea = patch(ax,...
            [0 0 0 0],...
            [0 p.h_max*1.08 p.h_max*1.08 0],...
            [0.48 0.64 0.86],...
            'FaceAlpha',0.28,...
            'EdgeColor','none',...
            'DisplayName','Prediction horizon (shaded)');
        ui.h1Past = plot(ax,NaN,NaN,...
            'Color',[0.00 0.35 0.75],...
            'LineStyle','-',...
            'LineWidth',2.0,...
            'DisplayName','h1 past');
        ui.h2Past = plot(ax,NaN,NaN,...
            'Color',[0.85 0.25 0.10],...
            'LineStyle','-',...
            'LineWidth',2.0,...
            'DisplayName','h2 past');
        ui.h1RefPast = plot(ax,NaN,NaN,...
            'Color',[0.20 0.65 0.95],...
            'LineStyle',':',...
            'LineWidth',2.0,...
            'DisplayName','h1 reference');
        ui.h2RefPast = plot(ax,NaN,NaN,...
            'Color',[0.60 0.20 0.75],...
            'LineStyle',':',...
            'LineWidth',2.0,...
            'DisplayName','h2 reference');
        ui.h1Prediction = plot(ax,NaN,NaN,...
            'Color',[0.00 0.60 0.35],...
            'LineStyle','--',...
            'Marker','o',...
            'MarkerSize',4,...
            'LineWidth',1.8,...
            'DisplayName','h1 prediction');
        ui.h2Prediction = plot(ax,NaN,NaN,...
            'Color',[0.95 0.65 0.05],...
            'LineStyle','--',...
            'Marker','d',...
            'MarkerSize',4,...
            'LineWidth',1.8,...
            'DisplayName','h2 prediction');
        ui.h1MaxLine = yline(ax,ui.h1MaxEdit.Value,...
            'Color',[0.30 0.30 0.30],...
            'LineStyle','--',...
            'LineWidth',1.2,...
            'DisplayName','Tank 1 max level');
        ui.h2MaxLine = yline(ax,ui.h2MaxEdit.Value,...
            'Color',[0.45 0.45 0.45],...
            'LineStyle','-.',...
            'LineWidth',1.2,...
            'DisplayName','Tank 2 max level');
        yyaxis(ax,'right');
        ylabel(ax,'Inlet flow q_in [cm^3/s]','Interpreter','none');
        ui.qPast = plot(ax,NaN,NaN,...
            'Color',[0.15 0.15 0.15],...
            'LineStyle','-',...
            'LineWidth',2.0,...
            'DisplayName','q_in past');
        ui.qPrediction = plot(ax,NaN,NaN,...
            'Color',[0.75 0.05 0.20],...
            'LineStyle','--',...
            'Marker','s',...
            'MarkerSize',4,...
            'LineWidth',1.8,...
            'DisplayName','q_in optimal sequence');
        ui.qMinLine = yline(ax,ui.qMinEdit.Value,...
            'Color',[0.35 0.35 0.35],...
            'LineStyle',':',...
            'LineWidth',1.1,...
            'HandleVisibility','off');
        ui.qMaxLine = yline(ax,ui.qMaxEdit.Value,...
            'Color',[0.35 0.35 0.35],...
            'LineStyle',':',...
            'LineWidth',1.1,...
            'HandleVisibility','off');
        ui.nowLine = xline(ax,0,...
            'Color',[0.10 0.10 0.10],...
            'LineStyle','-',...
            'LineWidth',1.2,...
            'DisplayName','Current simulation time');
        title(ax,...
            'Past signals + current prediction horizon',...
            'Interpreter','none',...
            'FontWeight','bold');
        % Refresh legend on demand: combined limit when both values agree.
        ui.maxLevelsCombined = [];
        updateMPCPlot();
    end
    function refreshMPClegend()
        handles = [ui.h1Past ui.h2Past ui.h1RefPast ui.h2RefPast ...
            ui.h1Prediction ui.h2Prediction ui.qPast ui.qPrediction ...
            ui.predictionArea ui.nowLine ui.h1MaxLine];
        if ~ui.maxLevelsCombined
            handles = [handles ui.h2MaxLine];
        end
        legend(ui.axMPC,handles,...
            'Location','northeast',...
            'NumColumns',2,...
            'FontSize',9,...
            'Interpreter','none');
    end
    function updateMPCPlot()
        if ~isfield(ui,'axMPC') || ~isvalid(ui.axMPC)
            return;
        end
        tNow = state.lastSimulationTime;
        P = round(ui.pEdit.Value);
        predictionEnd = tNow+P*p.mpcTs;
        predictionTime = tNow+(0:P)*p.mpcTs;
        yyaxis(ui.axMPC,'left');
        ui.h1Past.XData = state.t;
        ui.h1Past.YData = state.h1History;
        ui.h2Past.XData = state.t;
        ui.h2Past.YData = state.h2History;
        ui.h1RefPast.XData = state.t;
        ui.h1RefPast.YData = state.h1RefHistory;
        ui.h2RefPast.XData = state.t;
        ui.h2RefPast.YData = state.h2RefHistory;
        ui.h1MaxLine.Value = ui.h1MaxEdit.Value;
        ui.h2MaxLine.Value = ui.h2MaxEdit.Value;
        combinedLimits = abs(ui.h1MaxEdit.Value - ui.h2MaxEdit.Value)<1e-9;
        if combinedLimits
            ui.h1MaxLine.DisplayName = 'Tank 1 and 2 max level';
            ui.h2MaxLine.Visible = 'off';
        else
            ui.h1MaxLine.DisplayName = 'Tank 1 max level';
            ui.h2MaxLine.Visible = 'on';
        end
        if isempty(ui.maxLevelsCombined) || ...
                ui.maxLevelsCombined ~= combinedLimits
            ui.maxLevelsCombined = combinedLimits;
            refreshMPClegend();
        end
        ui.predictionArea.XData = ...
            [tNow predictionEnd predictionEnd tNow];
        ui.predictionArea.YData = ...
            [0 0 p.h_max*1.08 p.h_max*1.08];
        if ~isempty(state.yseq)
            ys = state.yseq;
            if isvector(ys)
                ys = ys(:);
            end
            n = min(size(ys,1),numel(predictionTime));
            if size(ys,2) >= 1
                ui.h1Prediction.XData = predictionTime(1:n);
                ui.h1Prediction.YData = ys(1:n,1);
            else
                ui.h1Prediction.XData = NaN;
                ui.h1Prediction.YData = NaN;
            end
            if size(ys,2) >= 2
                ui.h2Prediction.XData = predictionTime(1:n);
                ui.h2Prediction.YData = ys(1:n,2);
            else
                ui.h2Prediction.XData = NaN;
                ui.h2Prediction.YData = NaN;
            end
        else
            ui.h1Prediction.XData = NaN;
            ui.h1Prediction.YData = NaN;
            ui.h2Prediction.XData = NaN;
            ui.h2Prediction.YData = NaN;
        end
        yyaxis(ui.axMPC,'right');
        ui.qPast.XData = state.t;
        ui.qPast.YData = state.qHistory;
        ui.qMinLine.Value = ui.qMinEdit.Value;
        ui.qMaxLine.Value = ui.qMaxEdit.Value;
        if ~isempty(state.mvseq)
            us = state.mvseq;
            if ~isvector(us)
                us = us(:,1);
            end
            us = us(:);
            n = min(numel(us),numel(predictionTime));
            ui.qPrediction.XData = predictionTime(1:n);
            ui.qPrediction.YData = us(1:n);
        else
            ui.qPrediction.XData = NaN;
            ui.qPrediction.YData = NaN;
        end
        ui.nowLine.Value = tNow;
        leftEdge = max(0,tNow-p.plotWindow);
        rightEdge = max(...
            p.plotWindow,tNow+P*p.mpcTs+p.plotLead);
        xlim(ui.axMPC,[leftEdge rightEdge]);
        title(ui.axMPC,...
            sprintf(...
            'Past signals + prediction horizon | P = %d | M = %d | Ts = %.2f s',...
            P,round(ui.mEdit.Value),p.mpcTs),...
            'Interpreter','none',...
            'FontWeight','bold');
    end

%% Tank animation
    function buildTankView()
        ax = ui.axTank;
        cla(ax);
        hold(ax,'on');
        ax.XTick = [];
        ax.YTick = [];
        ax.Box = 'off';
        ax.Color = [0.985 0.985 0.985];
        xlim(ax,[0 18.7]);
        ylim(ax,[0 41.0]);
        title(ax,'Quanser-like coupled tanks | hydraulic flow schematic',...
            'Interpreter','none','FontWeight','bold');
        pipeColor = [0.24 0.29 0.35];
        waterColor = [0.11 0.54 0.91];
        waterLineColor = [0.29 0.70 0.94];
        refColor1 = [0.15 0.65 0.30];
        refColor2 = [0.85 0.30 0.15];
        valveColor = [0.62 0.34 0.30];
        x1 = geo.tank1X;
        x2 = geo.tank2X;
        b1 = geo.tank1Bottom;
        b2 = geo.tank2Bottom;
        W = geo.tankWidth;
        H = geo.tankHeight;
        c1 = x1+W/2;
        c2 = x2+W/2;
        % Hydraulics of the ACTUAL model:
        % Reservoir -> pump -> main inlet -> upper Tank 1;
        % gamma = 0.5 => secondary inlet to lower Tank 2.
        % Tank 1 bottom outlet -> Tank 2 -> reservoir.
        % Extra Tank 1 drain tap -> reservoir is a real hardware option,
        % but is closed here and is NOT present in this Simscape plant.
        geo.pumpPath = [geo.resX 2.55; 14.40 2.55; ...
            geo.splitX 2.55; geo.splitX 38.0; c1 38.0; c1 b1+H];
        geo.inlet1Path = [geo.splitX 19.95; geo.splitX 38.0; ...
            c1 38.0; c1 b1+H];
        geo.inlet2Path = [geo.splitX 19.95; 6.95 19.95; ...
            6.95 b2+H; c2 b2+H];
        geo.couplingPath = [c1 b1; c2 b2+H];
        geo.outletPath = [x2+W b2+1.0; 14.25 b2+1.0; ...
            14.25 4.65; geo.resX 4.65];
        % A single horizontal run from Tank 1, then vertically into
        % the reservoir (closed drain branch, visual hardware only).
        geo.drainTapPath = [x1+W b1+1.20; ...
            geo.resX+1.05 b1+1.20; geo.resX+1.05 5.40];
        % Plumbing is behind the tanks and the flowing liquid.
        drawPipe(geo.pumpPath,pipeColor,4.0);
        drawPipe(geo.inlet2Path,pipeColor,3.4);
        drawPipe(geo.couplingPath,pipeColor,5.5);
        drawPipe(geo.outletPath,pipeColor,4.4);
        drawPipe(geo.pumpPath,waterLineColor,1.4);
        drawPipe(geo.inlet2Path,waterLineColor,1.25);
        drawPipe(geo.couplingPath,waterLineColor,2.0);
        drawPipe(geo.outletPath,waterLineColor,1.5);
        % Closed upper drain tap: dashed / dry pipe, no moving water.
        plot(ax,geo.drainTapPath(:,1),geo.drainTapPath(:,2),':',...
            'Color',[0.58 0.58 0.58],'LineWidth',2.0,...
            'HandleVisibility','off');
        % Valve symbol (normally closed): opposing diagonal gates.
        vx = 13.95;
        vy = b1+1.20;
        plot(ax,[vx-0.21 vx+0.21],[vy-0.75 vy+0.75],'-',...
            'Color',valveColor,'LineWidth',2.3,'HandleVisibility','off');
        plot(ax,[vx-0.21 vx+0.21],[vy+0.75 vy-0.75],'-',...
            'Color',valveColor,'LineWidth',2.3,'HandleVisibility','off');
        % Reservoir and pump: recirculating closed-loop equipment.
        rectangle(ax,'Position',[geo.resX 1.25 2.1 4.15],...
            'EdgeColor',pipeColor,'LineWidth',1.8,...
            'FaceColor',[0.92 0.96 0.98]);
        patch(ax,[geo.resX+0.07 geo.resX+2.03 geo.resX+2.03 geo.resX+0.07],...
            [1.32 1.32 3.05 3.05],waterColor,...
            'EdgeColor','none','FaceAlpha',0.44);
        rectangle(ax,'Position',[12.55 1.96 0.91 1.28],...
            'Curvature',[1 1],'EdgeColor',[0.10 0.32 0.53],...
            'LineWidth',1.8,'FaceColor',[0.91 0.95 0.99]);
        patch(ax,[12.89 13.15 12.89],[2.14 2.58 3.00],...
            [0.13 0.47 0.77],'EdgeColor','none');
        % Fluid levels are the measured live h1, h2 signals.
        ui.tank1Liquid = patch(ax,[x1 x1+W x1+W x1],...
            [b1 b1 b1 b1],waterColor,'EdgeColor','none',...
            'FaceAlpha',0.68);
        ui.tank2Liquid = patch(ax,[x2 x2+W x2+W x2],...
            [b2 b2 b2 b2],waterColor,'EdgeColor','none',...
            'FaceAlpha',0.68);
        rectangle(ax,'Position',[x1 b1 W H],...
            'EdgeColor',[0.12 0.12 0.12],'LineWidth',2.4,...
            'FaceColor','none');
        rectangle(ax,'Position',[x2 b2 W H],...
            'EdgeColor',[0.12 0.12 0.12],'LineWidth',2.4,...
            'FaceColor','none');
        ui.tank1RefLine = plot(ax,[x1 x1+W],[b1 b1],'--',...
            'Color',refColor1,'LineWidth',2);
        ui.tank2RefLine = plot(ax,[x2 x2+W],[b2 b2],'--',...
            'Color',refColor2,'LineWidth',2);
        % Blue dots indicate qualitative direction, not measured flow rate.
        dotColor = [0.03 0.42 0.82];
        ui.pumpDots = plot(ax,NaN,NaN,'o',...
            'MarkerSize',5.0,'MarkerFaceColor',dotColor,...
            'MarkerEdgeColor','none','HandleVisibility','off');
        ui.inlet2Dots = plot(ax,NaN,NaN,'o',...
            'MarkerSize',5.0,'MarkerFaceColor',dotColor,...
            'MarkerEdgeColor','none','HandleVisibility','off');
        ui.couplingDots = plot(ax,NaN,NaN,'o',...
            'MarkerSize',5.0,'MarkerFaceColor',dotColor,...
            'MarkerEdgeColor','none','HandleVisibility','off');
        ui.outletDots = plot(ax,NaN,NaN,'o',...
            'MarkerSize',5.0,'MarkerFaceColor',dotColor,...
            'MarkerEdgeColor','none','HandleVisibility','off');
        % Tank names to the left of each vessel, clear of inlet pipes.
        text(ax,x1-0.30,b1+H*0.54,'Tank 1',...
            'HorizontalAlignment','right','FontWeight','bold',...
            'FontSize',10,'Interpreter','none');
        text(ax,x2-0.30,b2+H*0.54,'Tank 2',...
            'HorizontalAlignment','right','FontWeight','bold',...
            'FontSize',10,'Interpreter','none');
        ui.tank1LevelText = text(ax,10.55,32.0,'h1 = 0.00 cm',...
            'HorizontalAlignment','left','FontWeight','bold',...
            'FontSize',10,'Interpreter','none');
        ui.tank2LevelText = text(ax,10.55,14.35,'h2 = 0.00 cm',...
            'HorizontalAlignment','left','FontWeight','bold',...
            'FontSize',10,'Interpreter','none');
        ui.qText = text(ax,3.40,39.20,'q_in = 0.00 cm^3/s',...
            'HorizontalAlignment','left','FontWeight','bold',...
            'FontSize',10,'Interpreter','none');
        ui.splitText = text(ax,3.45,21.15,...
            sprintf('To Tank 2: %.0f%% of pump flow',100*(1-p.gamma)),...
            'HorizontalAlignment','left','FontSize',9,...
            'Color',[0.24 0.29 0.37],'Interpreter','none');
        text(ax,3.45,33.60,...
            sprintf('To Tank 1: %.0f%% of pump flow',100*p.gamma),...
            'HorizontalAlignment','left','FontSize',9,...
            'Color',[0.24 0.29 0.37],'Interpreter','none');
        text(ax,10.55,20.80,'Gravity: Tank 1 to Tank 2',...
            'HorizontalAlignment','left','FontSize',9,...
            'Interpreter','none');
        text(ax,14.30,25.80,'Drain tap: CLOSED',...
            'HorizontalAlignment','left','FontSize',9,...
            'Color',valveColor,'FontWeight','bold',...
            'Interpreter','none');
        text(ax,14.30,24.75,'(hardware only)',...
            'HorizontalAlignment','left','FontSize',8,...
            'Color',[0.5 0.5 0.5],'Interpreter','none');
        % Put reservoir name inside its enclosure; the drain enters at top.
        text(ax,geo.resX+1.05,4.07,'Reservoir',...
            'HorizontalAlignment','center','FontWeight','bold',...
            'FontSize',10,'Interpreter','none');
        text(ax,13.00,4.06,'Pump',...
            'HorizontalAlignment','center','FontWeight','bold',...
            'FontSize',9,'Interpreter','none');
        updateTankView();
    end
    function drawPipe(path,color,thickness)
        plot(ui.axTank,path(:,1),path(:,2),'-',...
            'Color',color,'LineWidth',thickness,'HandleVisibility','off');
    end
    function updateTankView()
        if ~isfield(ui,'tank1Liquid') || ~isvalid(ui.tank1Liquid)
            return;
        end
        h1Draw = min(max(state.h1,0),p.h_max);
        h2Draw = min(max(state.h2,0),p.h_max);
        b1 = geo.tank1Bottom;
        b2 = geo.tank2Bottom;
        y1 = b1+h1Draw*geo.scale;
        y2 = b2+h2Draw*geo.scale;
        x1 = geo.tank1X;
        x2 = geo.tank2X;
        W = geo.tankWidth;
        ui.tank1Liquid.XData = [x1 x1+W x1+W x1];
        ui.tank1Liquid.YData = [b1 b1 y1 y1];
        ui.tank2Liquid.XData = [x2 x2+W x2+W x2];
        ui.tank2Liquid.YData = [b2 b2 y2 y2];
        ref1Y = b1+state.currentH1Ref*geo.scale;
        ref2Y = b2+state.currentH2Ref*geo.scale;
        ui.tank1RefLine.YData = [ref1Y ref1Y];
        ui.tank2RefLine.YData = [ref2Y ref2Y];
        ui.tank1LevelText.String = sprintf(...
            'h1 = %.2f cm | ref = %.2f cm',...
            state.h1,state.currentH1Ref);
        ui.tank2LevelText.String = sprintf(...
            'h2 = %.2f cm | ref = %.2f cm',...
            state.h2,state.currentH2Ref);
        ui.qText.String = sprintf('q_in = %.2f cm^3/s',state.q);
        if state.h1 >= ui.h1MaxEdit.Value
            ui.tank1LevelText.Color = [0.75 0.05 0.05];
        else
            ui.tank1LevelText.Color = [0.10 0.10 0.10];
        end
        if state.h2 >= ui.h2MaxEdit.Value
            ui.tank2LevelText.Color = [0.75 0.05 0.05];
        else
            ui.tank2LevelText.Color = [0.10 0.10 0.10];
        end
        % Actual live h, q drive animation; inter-tank flow is not measured.
        flowFraction = min(max(state.q/max(ui.qMaxEdit.Value,1),0),1);
        currentT = state.lastSimulationTime;
        pumpActive = state.q > 1e-3;
        toLowerActive = pumpActive && (1-p.gamma)>1e-6;
        couplingActive = state.h1 > 0.05;
        outletActive = state.h2 > 0.05;
        animatePipeDots(ui.pumpDots,geo.pumpPath,...
            currentT,9,0.21+0.32*flowFraction,pumpActive,0.0);
        animatePipeDots(ui.inlet2Dots,geo.inlet2Path,...
            currentT,4,0.28+0.22*flowFraction,toLowerActive,0.18);
        animatePipeDots(ui.couplingDots,geo.couplingPath,...
            currentT,3,0.18+0.25*min(h1Draw/p.h_max,1),couplingActive,0.15);
        animatePipeDots(ui.outletDots,geo.outletPath,...
            currentT,4,0.25+0.24*min(h2Draw/p.h_max,1),outletActive,0.35);
    end
    function animatePipeDots(handle,path,t,n,rate,active,offset)
        if ~active
            handle.XData = NaN;
            handle.YData = NaN;
            return;
        end
        distances = [0; cumsum(hypot(diff(path(:,1)),diff(path(:,2))))];
        if distances(end) <= 0
            return;
        end
        fractions = mod(t*rate+offset+(0:n-1)/n,1);
        position = fractions*distances(end);
        handle.XData = interp1(distances,path(:,1),position,'linear');
        handle.YData = interp1(distances,path(:,2),position,'linear');
    end

%% Live information
    function updateLiveValues()
        ui.h1Value.Text = sprintf('%.3f',state.h1);
        ui.h2Value.Text = sprintf('%.3f',state.h2);
        ui.qValue.Text = sprintf('%.3f',state.q);
        if isfinite(state.cost)
            ui.costValue.Text = sprintf('%.4g',state.cost);
        else
            ui.costValue.Text = '—';
        end
        if isfinite(state.qpStatus)
            ui.qpValue.Text = sprintf('%d',round(state.qpStatus));
        else
            ui.qpValue.Text = '—';
        end
        % Compute challenge scores using the final measured levels, not MPC
        % predictions. While running, use the active references. After a
        % completed run, retain the last references stored with the samples
        % so editing a reference afterward does not alter the final score.
        if ~isempty(state.t) && isfinite(state.h1) && isfinite(state.h2)
            r1 = state.currentH1Ref;
            r2 = state.currentH2Ref;
            if ~(state.running || state.starting) && ...
                    ~isempty(state.h1RefHistory) && ...
                    ~isempty(state.h2RefHistory)
                r1 = state.h1RefHistory(end);
                r2 = state.h2RefHistory(end);
            end
            e1 = abs(state.h1-r1);
            e2 = abs(state.h2-r2);
            ui.h1ErrorValue.Text = sprintf('%.3f',e1);
            ui.h2ErrorValue.Text = sprintf('%.3f',e2);
            ui.totalErrorValue.Text = sprintf('%.3f',e1+e2);
        else
            % Avoid displaying a competition score before any level sample.
            ui.h1ErrorValue.Text = '—';
            ui.h2ErrorValue.Text = '—';
            ui.totalErrorValue.Text = '—';
        end
    end

%% Defaults
    function restoreDefaults(~,~)
        setReference(1,p.h1_ref);
        setReference(2,p.h2_ref);
        ui.pSlider.Value = p.predictionHorizon;
        ui.pEdit.Value = p.predictionHorizon;
        ui.mSlider.Value = p.controlHorizon;
        ui.mEdit.Value = p.controlHorizon;
        ui.wy1Slider.Value = p.wy1;
        ui.wy1Edit.Value = p.wy1;
        ui.wy2Slider.Value = p.wy2;
        ui.wy2Edit.Value = p.wy2;
        ui.wuSlider.Value = p.wu;
        ui.wuEdit.Value = p.wu;
        ui.wduSlider.Value = p.wdu;
        ui.wduEdit.Value = p.wdu;
        ui.qMinSlider.Value = p.q_min;
        ui.qMinEdit.Value = p.q_min;
        ui.qMaxSlider.Value = p.q_max;
        ui.qMaxEdit.Value = p.q_max;
        ui.h1MaxSlider.Value = p.h1_max;
        ui.h1MaxEdit.Value = p.h1_max;
        ui.h2MaxSlider.Value = p.h2_max;
        ui.h2MaxEdit.Value = p.h2_max;
        applyHorizon('P',p.predictionHorizon);
        applyHorizon('M',p.controlHorizon);
        applyWeightValues();
        applyConstraintValues();
        ui.stopTimeEdit.Value = p.t_stop;
        ui.pacingEnabled.Value = p.pacingEnabled;
        ui.pacingSlider.Value = p.pacingRate;
        ui.pacingEdit.Value = p.pacingRate;
        applyPacing();
        setStatus('Default laboratory parameters restored.');
    end

%% Parameter publication
    function publishBaseVariables()
        assignin('base','mpcController',mpcController);
        assignin('base','T_water',p.T_water);
        assignin('base','p_env',p.p_env);
        assignin('base','g',p.g);
        assignin('base','A_tank',p.A_tank);
        assignin('base','h_max',p.h_max);
        assignin('base','V_max',p.V_max);
        assignin('base','A_12',p.A_12);
        assignin('base','A_out',p.A_out);
        assignin('base','mpc_Pmax',p.maxPredictionHorizon);
        assignin('base','h_ports_T1',p.h_ports_T1);
        assignin('base','A_ports_T1',p.A_ports_T1);
        assignin('base','h_ports_T2',p.h_ports_T2);
        assignin('base','A_ports_T2',p.A_ports_T2);
        assignin('base','h1_0',p.h1_0);
        assignin('base','h2_0',p.h2_0);
        assignin('base','gamma',p.gamma);
        assignin('base','h1_ref',state.currentH1Ref);
        assignin('base','h2_ref',state.currentH2Ref);
        assignin('base','q_in_initial',p.q_in_initial);
        assignin('base','q_in_step',p.q_in_step);
        assignin('base','t_step',p.t_step);
        assignin('base','mpc_Ts',p.mpcTs);
        assignin('base','mpc_P',...
            round(uiValueOrDefault('P',p.predictionHorizon)));
        assignin('base','mpc_M',...
            round(uiValueOrDefault('M',p.controlHorizon)));
        assignin('base','mpc_Wy',...
            [uiValueOrDefault('Wy1',p.wy1) ...
            uiValueOrDefault('Wy2',p.wy2)]);
        assignin('base','mpc_Wu',...
            uiValueOrDefault('Wu',p.wu));
        assignin('base','mpc_Wdu',...
            uiValueOrDefault('Wdu',p.wdu));
        assignin('base','mpc_ymin',...
            [p.h1_min p.h2_min]);
        assignin('base','mpc_ymax',...
            [uiValueOrDefault('h1Max',p.h1_max) ...
            uiValueOrDefault('h2Max',p.h2_max)]);
        assignin('base','mpc_umin',...
            uiValueOrDefault('qMin',p.q_min));
        assignin('base','mpc_umax',...
            uiValueOrDefault('qMax',p.q_max));
    end
    function value = uiValueOrDefault(name,defaultValue)
        value = defaultValue;
        if ~exist('ui','var') || ~isstruct(ui)
            return;
        end
        try
            switch name
                case 'P'
                    value = ui.pEdit.Value;
                case 'M'
                    value = ui.mEdit.Value;
                case 'Wy1'
                    value = ui.wy1Edit.Value;
                case 'Wy2'
                    value = ui.wy2Edit.Value;
                case 'Wu'
                    value = ui.wuEdit.Value;
                case 'Wdu'
                    value = ui.wduEdit.Value;
                case 'qMin'
                    value = ui.qMinEdit.Value;
                case 'qMax'
                    value = ui.qMaxEdit.Value;
                case 'h1Max'
                    value = ui.h1MaxEdit.Value;
                case 'h2Max'
                    value = ui.h2MaxEdit.Value;
                case 'stopTime'
                    value = ui.stopTimeEdit.Value;
            end
        catch
        end
    end

%% Model configuration
    function configureModel()
        pacingOn = p.pacingEnabled;
        pacingRate = p.pacingRate;
        if isfield(ui,'pacingEnabled') && isvalid(ui.pacingEnabled)
            pacingOn = ui.pacingEnabled.Value;
        end
        if isfield(ui,'pacingEdit') && isvalid(ui.pacingEdit)
            pacingRate = ui.pacingEdit.Value;
        end
        stopTime = uiValueOrDefault('stopTime',p.t_stop);
        set_param(mdl,'FastRestart','off','SimulationMode','normal',...
            'StopTime',num2str(stopTime,16),'MaxStep',num2str(p.maxStep,16));
        % Simscape logging was enabled for the entire physical network in the
        % submitted model. It is useful for debugging, but it makes this
        % interactive lab much slower and is not needed by the GUI.
        try
            set_param(mdl,'SimscapeLogType','none');
            set_param(mdl,'SimscapeLogSimulationStatistics','off');
        catch
        end
        try
            if pacingOn
                set_param(mdl,'EnablePacing','on','PacingRate',num2str(pacingRate,16));
            else
                set_param(mdl,'EnablePacing','off');
            end
        catch ME
            warning('Could not configure pacing: %s',ME.message);
        end
    end
    function configureSignalLogging()
        try
            set_param(mdl,'SignalLogging','on','SignalLoggingName','logsout','ReturnWorkspaceOutputs','on');
            % Explicitly log the two physical outputs required to redraw
            % a complete run after a no-pacing simulation ends.
            levelMux = findBlockByNameOptional(mdl,'Mux',1);
            if ~isempty(levelMux)
                Simulink.sdi.markSignalForStreaming(levelMux,1,'on');
            end
            if ~isempty(mpcSubsystem)
                Simulink.sdi.markSignalForStreaming(mpcSubsystem,1,'on');
            end
            % The four MPC diagnostic ports are already instrumented in
            % S5_MPC_Lab; keep them available for final-value recovery too.
            if ~isempty(mpcBlock)
                for portNumber = 2:5
                    Simulink.sdi.markSignalForStreaming(mpcBlock,portNumber,'on');
                end
            end
        catch ME
            warning('Could not configure signal logging: %s',ME.message);
        end
    end
    function applyReferenceValues()
        assignin('base','h1_ref',state.currentH1Ref);
        assignin('base','h2_ref',state.currentH2Ref);
        set_param(h1RefBlock,...
            'Value',num2str(state.currentH1Ref,16));
        set_param(h2RefBlock,...
            'Value',num2str(state.currentH2Ref,16));
    end
    function applyAllLiveMPCValues()
        P = round(uiValueOrDefault('P',p.predictionHorizon));
        M = min(round(uiValueOrDefault('M',p.controlHorizon)),P);
        Wy = [uiValueOrDefault('Wy1',p.wy1) uiValueOrDefault('Wy2',p.wy2)];
        Wu = uiValueOrDefault('Wu',p.wu);
        Wdu = uiValueOrDefault('Wdu',p.wdu);
        yMin = [p.h1_min p.h2_min];
        yMax = [uiValueOrDefault('h1Max',p.h1_max) uiValueOrDefault('h2Max',p.h2_max)];
        uMin = uiValueOrDefault('qMin',p.q_min);
        uMax = uiValueOrDefault('qMax',p.q_max);
        assignin('base','mpc_P',P);
        assignin('base','mpc_M',M);
        assignin('base','mpc_Wy',Wy);
        assignin('base','mpc_Wu',Wu);
        assignin('base','mpc_Wdu',Wdu);
        assignin('base','mpc_ymin',yMin);
        assignin('base','mpc_ymax',yMax);
        assignin('base','mpc_umin',uMin);
        assignin('base','mpc_umax',uMax);
        syncMPCControllerFromUI();
    end
    function syncMPCControllerFromUI()
        P = round(uiValueOrDefault('P',p.predictionHorizon));
        M = min(round(uiValueOrDefault('M',p.controlHorizon)),P);
        Wy = [uiValueOrDefault('Wy1',p.wy1) uiValueOrDefault('Wy2',p.wy2)];
        Wu = uiValueOrDefault('Wu',p.wu);
        Wdu = uiValueOrDefault('Wdu',p.wdu);
        yMin = [p.h1_min p.h2_min];
        yMax = [uiValueOrDefault('h1Max',p.h1_max) uiValueOrDefault('h2Max',p.h2_max)];
        uMin = uiValueOrDefault('qMin',p.q_min);
        uMax = uiValueOrDefault('qMax',p.q_max);
        mpcController.PredictionHorizon = P;
        mpcController.ControlHorizon = M;
        mpcController.Weights.OutputVariables = Wy;
        mpcController.Weights.ManipulatedVariables = Wu;
        mpcController.Weights.ManipulatedVariablesRate = Wdu;
        if numel(mpcController.MV) >= 1
            mpcController.MV(1).Min = uMin;
            mpcController.MV(1).Max = uMax;
        end
        if numel(mpcController.OV) >= 1
            mpcController.OV(1).Min = yMin(1);
            mpcController.OV(1).Max = yMax(1);
        end
        if numel(mpcController.OV) >= 2
            mpcController.OV(2).Min = yMin(2);
            mpcController.OV(2).Max = yMax(2);
        end
        assignin('base','mpcController',mpcController);
        if ~isempty(mpcBlock)
            try
                set_param(mpcBlock,'mpcobj','mpcController');
            catch
            end
        end
    end

%% Controller interface
    function refreshControllerBlocks()
        mpcBlock = findBlockByNameOptional(mpcSubsystem,'MPC Controller',2);
        firstOrderHoldBlock = findBlockByNameOptional(mpcSubsystem,'First Order Hold',2);
        plantScopeBlock = findBlockByNameOptional(plantSubsystem,'h',2);
        if ~isempty(mpcBlock)
            assignin('base','mpcController',mpcController);
            set_param(mpcBlock,'mpcobj','mpcController');
            configureMPCDiagnosticPorts();
        end
    end
    function configureMPCDiagnosticPorts()
        if isempty(mpcBlock)
            return;
        end
        diagnosticParameters = {'return_cost','return_qpstatus','return_mvseq','return_ovseq'};
        for kk = 1:numel(diagnosticParameters)
            try
                set_param(mpcBlock,diagnosticParameters{kk},'on');
            catch
            end
        end
    end
    function validateControllerInterface()
        if isempty(mpcBlock)
            error('The MPC Controller block could not be found inside the Model Predictive Control subsystem.');
        end
        controllerName = get_param(mpcBlock,'mpcobj');
        if isempty(controllerName)
            error('The MPC Controller block does not have an MPC object assigned.');
        end
        if ~strcmp(strtrim(controllerName),'mpcController')
            set_param(mpcBlock,'mpcobj','mpcController');
        end
    end
    function updateControllerAvailabilityStatus()
        refreshControllerBlocks();
        if isempty(mpcBlock)
            setStatus('GUI ready, but the MPC Controller block was not found.');
        else
            setStatus('GUI ready. MPC controller loaded automatically.');
        end
    end

%% Validation
    function validateInputs()
        if ~isfinite(ui.stopTimeEdit.Value) || ui.stopTimeEdit.Value < 0.5
            error('Stop time must be a finite value >= 0.5 s.');
        end
        if ui.qMinEdit.Value >= ui.qMaxEdit.Value
            error('The minimum inlet flow must be smaller than the maximum inlet flow.');
        end
        if ui.mEdit.Value > ui.pEdit.Value
            error('The control horizon M cannot be greater than prediction horizon P.');
        end
        if ui.h1MaxEdit.Value <= p.h1_min || ...
                ui.h2MaxEdit.Value <= p.h2_min
            error('Maximum tank levels must be greater than minimum levels.');
        end
        if ui.wy1Edit.Value == 0 && ...
                ui.wy2Edit.Value == 0
            error('At least one output tracking weight must be greater than zero.');
        end
    end

%% Simulation lifecycle
    function monitorSimulation(~,~)
        if ~isvalid(fig) || ~bdIsLoaded(mdl)
            return;
        end
        try
            status = get_param(mdl,'SimulationStatus');
            % A timer callback may execute while the 'start' command is
            % still compiling the model. Until the running state has been
            % observed, 'stopped' must NOT end the GUI session.
            if strcmp(status,'running') && state.starting
                state.starting = false;
                state.running = true;
                ui.pauseButton.Enable = 'on';
                ui.stopButton.Enable = 'on';
            end
            if strcmp(status,'running') && state.running && ~state.paused
                processLiveData();
                if ~isempty(state.t)
                    updateLiveValues();
                    updateTankView();
                    updateMPCPlot();
                    ui.pauseButton.Text = 'Pause';
                    setStatus(sprintf('Running | t = %.2f s | P = %d | M = %d',state.lastSimulationTime,round(ui.pEdit.Value),round(ui.mEdit.Value)));
                    drawnow limitrate nocallbacks;
                elseif ~state.liveWarningShown && ~isempty(state.liveTimerStart) && toc(state.liveTimerStart) > 1.5
                    missing = find(state.live.packetCount(1:2) < 1);
                    if isempty(missing)
                        setStatus('Running. Live packets received; waiting for synchronized samples...');
                    else
                        names = {'h','q_in'};
                        setStatus(sprintf('Running, but waiting for live data: %s',strjoin(names(missing),', ')));
                    end
                    state.liveWarningShown = true;
                end
            elseif strcmp(status,'stopped') && state.running && ~state.starting
                finalizeCompletedRun();
            elseif strcmp(status,'paused')
                ui.pauseButton.Text = 'Continue';
            elseif strcmp(status,'running')
                ui.pauseButton.Text = 'Pause';
            end
        catch ME
            if state.running
                setStatus(['Live monitor error: ' ME.message]);
            end
        end
    end
    function finalizeCompletedRun()
        % Preserve the receiver while the SDI run is being finalized:
        % unpaced simulations may deliver callback packets after StopTime.
        if isempty(state.finalizeClock)
            state.finalizeClock = tic;
        end
        processLiveData();
        % The live timer may never have fired in an unpaced run. Read
        % the complete results from SDI, not merely the last live packet.
        needSDI = ~ui.pacingEnabled.Value || isempty(state.t);
        if needSDI && ~state.sdiRecovered
            if isempty(state.lastSDIAttempt) || toc(state.lastSDIAttempt) >= 0.25
                state.lastSDIAttempt = tic;
                state.sdiRecovered = restoreCompletedRunFromSDI();
            end
        end
        % If the live stream supplied the complete run, it is usable too.
        hadFullStream = ~isempty(state.t) && ...
            state.lastSimulationTime >= ui.stopTimeEdit.Value-0.2;
        if ~(state.sdiRecovered || hadFullStream || toc(state.finalizeClock) > 4)
            setStatus('Simulation finished. Loading recorded results...');
            return;
        end
        processLiveData();
        if ~isempty(state.t)
            updateLiveValues();
            updateTankView();
            updateMPCPlot();
            drawnow limitrate nocallbacks;
            setStatus(sprintf('Simulation finished | t = %.2f s',state.lastSimulationTime));
        else
            % Do not claim that plotting succeeded without any samples.
            setStatus('Simulation finished, but no logged h1/h2 data was found. Check SDI signal logging.');
        end
        state.starting = false;
        state.running = false;
        state.paused = false;
        state.finalizeClock = [];
        ui.pauseButton.Text = 'Pause';
        ui.pauseButton.Enable = 'off';
        ui.stopButton.Enable = 'off';
    end
    function runID = currentSDIRunID()
        runID = NaN;
        try
            theRun = Simulink.sdi.getCurrentSimulationRun(mdl);
            if ~isempty(theRun)
                runID = double(theRun.ID);
            end
        catch
            % Older releases may not have a current run yet.
        end
    end
    function recovered = restoreCompletedRunFromSDI()
        recovered = false;
        try
            theRun = Simulink.sdi.getCurrentSimulationRun(mdl);
            if isempty(theRun)
                return;
            end
            if isfinite(state.previousSDIRunID) && ...
                    double(theRun.ID) == state.previousSDIRunID
                return; % Never load samples from an earlier run.
            end
            signals = getAllSignals(theRun);
            if isempty(signals)
                return;
            end
            hSig = loggedSignal(signals,[mdl '/Mux'],1,'h');
            if isempty(hSig)
                return;
            end
            [ht, hv] = loggedTimeValues(hSig);
            [ht,hv] = normalizeVectorPacket(hv,ht,2);
            if isempty(ht)
                return;
            end
            % Wait briefly for the recorder to flush the end of a fast run.
            if ht(end) < ui.stopTimeEdit.Value - max(0.2,0.005*ui.stopTimeEdit.Value) && ...
                    toc(state.finalizeClock) < 3.5
                return;
            end
            qSig = loggedSignal(signals,[mdl '/Model Predictive Control'],1,'q_in');
            qt = []; qv = [];
            if ~isempty(qSig)
                [qt,qv] = loggedTimeValues(qSig);
                [qt,qv] = normalizeScalarPacket(qv,qt);
            end
            if ~isempty(qt)
                [qt,idx] = unique(qt,'stable');
                qv = qv(idx);
                if numel(qt)>1
                    qSamples = interp1(qt,qv,ht,'previous','extrap');
                else
                    qSamples = repmat(qv(end),size(ht));
                end
            else
                qSamples = qAtTimes(ht);
            end
            % Retain reference changes made during a partially live run.
            r1 = state.currentH1Ref*ones(size(ht));
            r2 = state.currentH2Ref*ones(size(ht));
            if ~isempty(state.t) && numel(state.t) == numel(state.h1RefHistory)
                [rt,ri] = unique(state.t,'stable');
                if numel(rt)>1
                    r1 = interp1(rt,state.h1RefHistory(ri),ht,'previous','extrap');
                    r2 = interp1(rt,state.h2RefHistory(ri),ht,'previous','extrap');
                end
            end
            state.t = ht(:).';
            state.h1History = hv(:,1).';
            state.h2History = hv(:,2).';
            state.qHistory = qSamples(:).';
            state.h1RefHistory = r1(:).';
            state.h2RefHistory = r2(:).';
            state.lastSampleTime = ht(end);
            state.lastSimulationTime = ht(end);
            state.h1 = hv(end,1);
            state.h2 = hv(end,2);
            state.q = qSamples(end);
            % These diagnostics are optional, but normally are logged.
            cBlock = [mdl '/Model Predictive Control/MPC Controller'];
            for k = 2:5
                sig = loggedSignal(signals,cBlock,k,'');
                if isempty(sig)
                    continue;
                end
                [dt,dv] = loggedTimeValues(sig);
                if isempty(dt) || isempty(dv)
                    continue;
                end
                switch k
                    case 2
                        [~,v] = normalizeScalarPacket(dv,dt);
                        if ~isempty(v), state.cost = v(end); end
                    case 3
                        v = lastLoggedSequence(dv,dt);
                        if ~isempty(v), state.mvseq = v; end
                    case 4
                        v = lastLoggedSequence(dv,dt);
                        if ~isempty(v), state.yseq = v; end
                    case 5
                        [~,v] = normalizeScalarPacket(dv,dt);
                        if ~isempty(v), state.qpStatus = v(end); end
                end
            end
            trimHistory();
            recovered = true;
        catch ME
            % The live stream still works if SDI retrieval is unavailable.
            if ~isempty(state.finalizeClock) && toc(state.finalizeClock)>3
                warning('SDI post-run recovery: %s',ME.message);
            end
        end
    end
    function sig = loggedSignal(signals,blockPath,port,nameFallback)
        sig = [];
        for k = 1:numel(signals)
            s = signals(k);
            try
                if double(s.PortIndex) ~= port
                    continue;
                end
                bp = s.BlockPath;
                if isa(bp,'Simulink.SimulationData.BlockPath')
                    cells = convertToCell(bp);
                    if isempty(cells), continue; end
                    thisPath = char(cells{end});
                else
                    thisPath = char(bp);
                end
                if strcmp(thisPath,blockPath)
                    sig = s;
                    return;
                end
            catch
            end
        end
        % Signal labels are an alternative when SDI reports a proxy path.
        if ~isempty(nameFallback)
            for k = 1:numel(signals)
                try
                    if strcmpi(char(signals(k).Name),nameFallback)
                        sig = signals(k);
                        return;
                    end
                catch
                end
            end
        end
    end
    function frame = lastLoggedSequence(data,time)
        % SDI stores the entire time history, unlike the one-frame
        % callback. Extract the last time sample before plotting the
        % receding-horizon sequences.
        frame = [];
        if isempty(data) || isempty(time)
            return;
        end
        nTime = numel(time);
        d = double(data);
        if ndims(d)>=3
            if size(d,1)==nTime
                frame = squeeze(d(end,:,:));
            elseif size(d,ndims(d))==nTime
                frame = squeeze(d(:,:,end));
            end
        elseif ismatrix(d)
            if nTime>1 && size(d,1)==nTime
                frame = d(end,:).';
            elseif nTime>1 && size(d,2)==nTime
                frame = d(:,end);
            else
                frame = d;
            end
        end
        if isempty(frame) || ~any(isfinite(frame(:)))
            frame = [];
        end
    end
    function [tt,vv] = loggedTimeValues(sig)
        tt = [];
        vv = [];
        try
            ts = sig.Values;
            if isa(ts,'timeseries')
                tt = double(ts.Time(:));
                vv = double(ts.Data);
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
        deleteListeners();
        state.starting = false;
        state.running = false;
        state.paused = false;
    end
    function deleteListeners()
        % Kept for compatibility with the original lifecycle code. Live
        % acquisition now uses Simulink Data Access callbacks, so there are
        % no block execution listeners to delete.
    end

%% Utilities
    function writeConstantBlock(block,value)
        if isempty(block)
            return;
        end
        try
            set_param(block,'Value',mat2str(value,16));
        catch ME
            warning(...
                'Could not update block "%s": %s',...
                block,ME.message);
        end
    end
    function value = firstFinite(data,defaultValue)
        value = defaultValue;
        try
            data = double(data);
            data = data(isfinite(data));
            if ~isempty(data)
                value = data(1);
            end
        catch
        end
    end
    function value = getBlockParameterSafe(...
            block,name,defaultValue)
        value = defaultValue;
        if isempty(block)
            return;
        end
        try
            value = get_param(block,name);
        catch
        end
    end
    function setStatus(message)
        if isfield(ui,'status') && isvalid(ui.status)
            ui.status.Text = message;
        end
    end
    function closeApp(~,~)
        try
            if bdIsLoaded(mdl) && ...
                    ~strcmp(get_param(mdl,'SimulationStatus'),'stopped')
                set_param(mdl,'SimulationCommand','stop');
                waitForStatus(mdl,'stopped',3);
            end
        catch
        end
        deleteListeners();
        try
            if isappdata(groot,'S5_MPC_LiveReceiver')
                rmappdata(groot,'S5_MPC_LiveReceiver');
            end
        catch
        end
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

%% MPC controller loading
    function controller = loadMPCController(fileName)
        if ~isfile(fileName)
            error('Cannot find MPC_TwoTank_Controller.mat in the same folder as run_TwoTank.m.');
        end
        data = load(fileName);
        names = fieldnames(data);
        controller = [];
        for jj = 1:numel(names)
            candidate = data.(names{jj});
            if isa(candidate,'mpc')
                controller = candidate;
                break;
            end
        end
        if isempty(controller)
            error('MPC_TwoTank_Controller.mat does not contain an MPC controller object.');
        end
    end

%% Block lookup
    function block = findBlockByName(...
            parent,targetName,searchDepth)
        block = findBlockByNameOptional(...
            parent,targetName,searchDepth);
        if isempty(block)
            error(...
                'Could not find block "%s" inside "%s".',...
                targetName,parent);
        end
    end
    function block = findBlockByNameOptional(...
            parent,targetName,searchDepth)
        blocks = find_system(parent,...
            'SearchDepth',searchDepth,...
            'LookUnderMasks','all',...
            'FollowLinks','on',...
            'Type','Block');
        target = normalizeName(targetName);
        block = '';
        for ii = 1:numel(blocks)
            current = get_param(blocks{ii},'Name');
            if strcmpi(normalizeName(current),target)
                block = blocks{ii};
                return;
            end
        end
    end
    function value = normalizeName(value)
        value = regexprep(value,'\s+',' ');
        value = strtrim(value);
    end
end
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
