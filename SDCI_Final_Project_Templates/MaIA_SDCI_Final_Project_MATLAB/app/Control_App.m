% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Provides the graphical interface for configuring, running, and reviewing simulations.

classdef Control_App < handle
    properties

        %% Model
        ModelName = 'MaIA_SDCI_Temperature_Control';

        %% Main window
        UIFigure
        MainGrid

        %% Control area
        ControlPanel
        ControlGrid

        %% Plot area
        PlotGrid
        TemperatureAxes
        ActuatorAxes

        %% Status indicator
        StatusGrid
        StatusLamp
        StatusLabel

        %% Experiment
        ExperimentNameField

        %% Setup
        ControllerDropDown
        ModelTypeDropDown
        ReferenceTitleLabel
        ReferenceRoomLabels
        ReferenceFields

        %% Environment
        AmbientTemperatureField
        DisturbanceEnabledCheckBox
        DisturbanceAmplitudeField
        DisturbanceStartField
        DisturbanceEndField
        DisturbanceRoomCheckBoxes
        DisturbanceAllRoomsCheckBox

        %% Simulation
        StopTimeField
        PacingEnabledCheckBox
        PacingRateSlider
        StartButton
        PauseButton
        StopButton
        ClearButton
        SaveMetricsButton

        %% Plot lines
        ReferenceLines
        MeasurementLines
        HeatLines

        %% Runtime
        UpdateTimer
        CurrentRunID = NaN
        LastFinalizedRunID = NaN
        SimulationWasActive = false
        LatestData
        LastRun
        ExperimentNameCustomized = false
        IsBusy = false
        ConfigurationDirty = true
        StopRequested = false
    end

    properties (Constant, Access = private)
        AppKey = 'Control_App_Instance';
        MaxPlotPoints = 5000;
        UpdatePeriod = 0.5;
        DefaultStopTimeMinutes = 30;
        DefaultDisturbanceAmplitude = 13;
        DefaultDisturbanceStartMinutes = 5;
        DefaultDisturbanceEndMinutes = 8;
        DefaultButtonColor = [0.94 0.94 0.94];
        StartActiveColor   = [0.72 0.88 0.72];
        PauseActiveColor   = [1.00 0.86 0.55];
        StopActiveColor    = [0.95 0.72 0.72];
        ReadyStatusColor   = [0.55 0.55 0.55];
        BusyStatusColor    = [0.95 0.62 0.15];
        RunningStatusColor = [0.25 0.70 0.35];
        PausedStatusColor  = [0.95 0.70 0.10];
        ErrorStatusColor   = [0.85 0.25 0.25];
    end

    %% PUBLIC METHODS
    methods

        function app = Control_App
            %% Load model
            if ~bdIsLoaded(app.ModelName)
                load_system(app.ModelName);
            end

            %% Runtime data
            app.LatestData = app.emptyDataStruct();
            app.LastRun = struct;

            %% Build interface
            app.createInterface();
            app.createPlotLines();

            %% Load current model configuration
            app.loadConfigurationFromWorkspace();

            %% Store singleton reference
            setappdata(0, app.AppKey, app);

            %% Start live update timer
            app.createUpdateTimer();

            %% Set initial button state
            try
                status = string( get_param( app.ModelName, 'SimulationStatus'));
            catch
                status = "stopped";
            end
            app.updateButtonStates(status);
            if status == "running"
                app.setStatus('Running', 'running');
            elseif status == "paused"
                app.setStatus('Paused', 'paused');
            else
                app.setStatus('Ready', 'ready');
            end

            %% Maximize
            app.bringToFront();
        end

        function bringToFront(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            app.UIFigure.Visible = 'on';
            app.UIFigure.WindowState = 'maximized';
            figure(app.UIFigure);
            drawnow;
        end
    end

    %% USER INTERFACE
    methods (Access = private)
        function createInterface(app)
            %% Main window
            app.UIFigure = uifigure( 'Name', 'MaIA_SDCI - Temperature Control', ...
                'WindowState', 'maximized', 'Color', [0.96 0.96 0.96]);
            app.UIFigure.CloseRequestFcn = @(~,~) app.closeApplication();

            %% Main layout
            app.MainGrid = uigridlayout( app.UIFigure, [1 2]);
            app.MainGrid.ColumnWidth = {370, '1x'};
            app.MainGrid.RowHeight = {'1x'};
            app.MainGrid.Padding = [10 10 10 10];
            app.MainGrid.ColumnSpacing = 10;

            %% LEFT SIDE - SINGLE CONTROL PANEL
            app.ControlPanel = uipanel( app.MainGrid, 'Title', 'Simulation Control', 'FontWeight', 'bold');
            app.ControlPanel.Layout.Row = 1;
            app.ControlPanel.Layout.Column = 1;
            app.ControlGrid = uigridlayout( app.ControlPanel, [18 1]);
            app.ControlGrid.RowHeight = { '1x', ... % Experiment
                '1x', ... % Controller
                '1x', ... % Model type
                22,   ... % References title
                '2x', ... % References
                22,   ... % Environment title
                '1x', ... % T_a
                '1x', ... % Disturbance enable
                '1x', ... % Amplitude
                '1x', ... % Start / end
                '2x', ... % Rooms
                22,   ... % Simulation title
                '1x', ... % Stop time
                '1x', ... % Pacing enable
                82,   ... % Pacing slider
                38,   ... % Start / pause / stop
                38,   ... % Clear / save
                28};      % Status indicator
            app.ControlGrid.Padding = [10 10 10 10];
            app.ControlGrid.RowSpacing = 5;

            %% Experiment name
            app.ExperimentNameField = app.addTextRow( app.ControlGrid, 1, 'Experiment', 'MaIA_SDCI_Run');
            app.ExperimentNameField.ValueChangedFcn = @(~,~) app.onExperimentNameChanged();

            %% Controller
            app.ControllerDropDown = app.addDropDownRow( app.ControlGrid, 2, 'Controller', { 'ON/OFF', ...
                'Fuzzy Logic', 'Model Predictive Control', 'Extremum Seeking Control', ...
                'Replicator Dynamics' }, [1 2 3 4 5]);
            app.ControllerDropDown.ValueChangedFcn = @(~,~) app.onControllerChanged();

            %% Model type
            app.ModelTypeDropDown = app.addDropDownRow( app.ControlGrid, 3, 'Model Type', { 'Block-Based', ...
                'Physics-Based' }, [1 2]);
            app.ModelTypeDropDown.ValueChangedFcn = @(~,~) app.onModelTypeChanged();

            %% Temperature references
            app.ReferenceTitleLabel = uilabel( app.ControlGrid, 'Text', 'Temperature References [°C]', ...
                'FontWeight', 'bold', 'FontSize', 11);
            app.ReferenceTitleLabel.Layout.Row = 4;
            referenceGrid = uigridlayout( app.ControlGrid, [1 4]);
            referenceGrid.Layout.Row = 5;
            referenceGrid.ColumnWidth = {'1x','1x','1x','1x'};
            referenceGrid.Padding = [0 0 0 0];
            referenceGrid.ColumnSpacing = 4;
            app.ReferenceRoomLabels = cell(4,1);
            app.ReferenceFields = cell(4,1);
            for i = 1:4
                roomGrid = uigridlayout( referenceGrid, [2 1]);
                roomGrid.RowHeight = {22, '1x'};
                roomGrid.Padding = [0 0 0 0];
                roomGrid.RowSpacing = 3;
                app.ReferenceRoomLabels{i} = uilabel( roomGrid, 'Text', sprintf('Room %d', i), ...
                    'HorizontalAlignment', 'center', 'FontSize', 10);
                app.ReferenceRoomLabels{i}.Layout.Row = 1;
                app.ReferenceFields{i} = uieditfield( roomGrid, 'numeric', 'Value', 20, 'Limits', [-50 100]);
                app.ReferenceFields{i}.Layout.Row = 2;
                app.ReferenceFields{i}.ValueChangedFcn = @(~,~) app.onReferenceChanged();
            end

            %% Environment title
            environmentLabel = uilabel( app.ControlGrid, 'Text', 'Environment', 'FontWeight', 'bold', ...
                'FontSize', 11);
            environmentLabel.Layout.Row = 6;

            %% Ambient temperature
            app.AmbientTemperatureField = app.addNumericRow( app.ControlGrid, 7, 'T_a [°C]', 8, [-50 60]);
            app.AmbientTemperatureField.ValueChangedFcn = @(~,~) app.autoApplyConfiguration();

            %% Disturbance enable
            app.DisturbanceEnabledCheckBox = uicheckbox( app.ControlGrid, ...
                'Text', 'Enable temperature disturbance');
            app.DisturbanceEnabledCheckBox.Layout.Row = 8;
            app.DisturbanceEnabledCheckBox.ValueChangedFcn = @(~,~) app.onDisturbanceEnabledChanged();

            %% Disturbance amplitude
            app.DisturbanceAmplitudeField = app.addNumericRow( app.ControlGrid, 9, 'Amplitude [°C]', ...
                app.DefaultDisturbanceAmplitude, [-50 50]);
            app.DisturbanceAmplitudeField.ValueChangedFcn = @(~,~) app.autoApplyConfiguration();

            %% Disturbance start / end
            disturbanceTimeGrid = uigridlayout( app.ControlGrid, [1 4]);
            disturbanceTimeGrid.Layout.Row = 10;
            disturbanceTimeGrid.ColumnWidth = {72, '1x', 65, '1x'};
            disturbanceTimeGrid.Padding = [0 0 0 0];
            disturbanceTimeGrid.ColumnSpacing = 6;
            uilabel( disturbanceTimeGrid, 'Text', 'Start [min]');
            app.DisturbanceStartField = uieditfield( disturbanceTimeGrid, 'numeric', ...
                'Value', app.DefaultDisturbanceStartMinutes, 'Limits', [0 Inf]);
            app.DisturbanceStartField.ValueChangedFcn = @(~,~) app.autoApplyConfiguration();
            uilabel( disturbanceTimeGrid, 'Text', 'End [min]');
            app.DisturbanceEndField = uieditfield( disturbanceTimeGrid, 'numeric', ...
                'Value', app.DefaultDisturbanceEndMinutes, 'Limits', [0 Inf]);
            app.DisturbanceEndField.ValueChangedFcn = @(~,~) app.autoApplyConfiguration();

            %% Affected rooms
            affectedRoomsGrid = uigridlayout( app.ControlGrid, [2 1]);
            affectedRoomsGrid.Layout.Row = 11;
            affectedRoomsGrid.RowHeight = {22, '1x'};
            affectedRoomsGrid.Padding = [0 0 0 0];
            affectedRoomsGrid.RowSpacing = 3;
            affectedLabel = uilabel( affectedRoomsGrid, 'Text', 'Affected Rooms', 'FontSize', 10);
            affectedLabel.Layout.Row = 1;
            roomSelectionGrid = uigridlayout( affectedRoomsGrid, [1 5]);
            roomSelectionGrid.Layout.Row = 2;
            roomSelectionGrid.ColumnWidth = {'1x','1x','1x','1x','1x'};
            roomSelectionGrid.Padding = [0 0 0 0];
            roomSelectionGrid.ColumnSpacing = 2;
            app.DisturbanceAllRoomsCheckBox = uicheckbox( roomSelectionGrid, 'Text', 'All');
            app.DisturbanceAllRoomsCheckBox.ValueChangedFcn = @(~,~) app.setAllDisturbanceRooms();
            app.DisturbanceRoomCheckBoxes = cell(4,1);
            for i = 1:4
                app.DisturbanceRoomCheckBoxes{i} = uicheckbox( roomSelectionGrid, 'Text', sprintf('%d', i));
                app.DisturbanceRoomCheckBoxes{i}.ValueChangedFcn = @(~,~) app.onDisturbanceRoomChanged();
            end

            %% Simulation title
            simulationLabel = uilabel( app.ControlGrid, 'Text', 'Simulation', 'FontWeight', 'bold', ...
                'FontSize', 11);
            simulationLabel.Layout.Row = 12;

            %% Stop time
            app.StopTimeField = app.addNumericRow( app.ControlGrid, 13, 'Stop Time [min]', ...
                app.DefaultStopTimeMinutes, [0.001 Inf]);
            app.StopTimeField.ValueChangedFcn = @(~,~) app.onStopTimeChanged();

            %% Pacing enable
            app.PacingEnabledCheckBox = uicheckbox( app.ControlGrid, 'Text', 'Enable simulation pacing', ...
                'Value', true);
            app.PacingEnabledCheckBox.Layout.Row = 14;
            app.PacingEnabledCheckBox.ValueChangedFcn = @(~,~) app.onPacingEnabledChanged();

            %% Pacing slider
            pacingGrid = uigridlayout( app.ControlGrid, [2 1]);
            pacingGrid.Layout.Row = 15;
            pacingGrid.RowHeight = {22, 42};
            pacingGrid.Padding = [0 4 0 14];
            pacingGrid.RowSpacing = 3;
            pacingLabel = uilabel( pacingGrid, 'Text', 'Pacing Rate [Sim s / Wall s]', 'FontSize', 10);
            pacingLabel.Layout.Row = 1;
            app.PacingRateSlider = uislider( pacingGrid, 'Limits', [70 200], 'Value', 100, ...
                'MajorTicks', [70 100 130 160 200], 'MajorTickLabels', {'70','100','130','160','200'});
            app.PacingRateSlider.Layout.Row = 2;
            app.PacingRateSlider.ValueChangedFcn = @(~,~) app.autoApplyConfiguration();

            %% START / PAUSE / STOP
            simulationButtonGrid = uigridlayout( app.ControlGrid, [1 3]);
            simulationButtonGrid.Layout.Row = 16;
            simulationButtonGrid.ColumnWidth = {'1x','1x','1x'};
            simulationButtonGrid.Padding = [0 0 0 0];
            simulationButtonGrid.ColumnSpacing = 5;
            app.StartButton = uibutton( simulationButtonGrid, 'push', 'Text', 'START', 'FontWeight', 'bold');
            app.StartButton.ButtonPushedFcn = @(~,~) app.startSimulation();
            app.PauseButton = uibutton( simulationButtonGrid, 'push', 'Text', 'PAUSE', 'FontWeight', 'bold');
            app.PauseButton.ButtonPushedFcn = @(~,~) app.pauseSimulation();
            app.StopButton = uibutton( simulationButtonGrid, 'push', 'Text', 'STOP', 'FontWeight', 'bold');
            app.StopButton.ButtonPushedFcn = @(~,~) app.stopSimulation();

            %% Clear / Save Metrics
            resultButtonGrid = uigridlayout( app.ControlGrid, [1 2]);
            resultButtonGrid.Layout.Row = 17;
            resultButtonGrid.ColumnWidth = {'1x','1x'};
            resultButtonGrid.Padding = [0 0 0 0];
            resultButtonGrid.ColumnSpacing = 5;
            app.ClearButton = uibutton( resultButtonGrid, 'push', 'Text', 'Clear Plots');
            app.ClearButton.ButtonPushedFcn = @(~,~) app.clearPlots();
            app.SaveMetricsButton = uibutton( resultButtonGrid, 'push', 'Text', 'Save Metrics', ...
                'FontWeight', 'bold');
            app.SaveMetricsButton.ButtonPushedFcn = @(~,~) app.saveMetrics();

            %% Status indicator
            % Keep the status indicator in the control panel.
            app.StatusGrid = uigridlayout( app.ControlGrid, [1 3]);
            app.StatusGrid.Layout.Row = 18;
            app.StatusGrid.ColumnWidth = {55, 18, '1x'};
            app.StatusGrid.Padding = [0 0 0 0];
            app.StatusGrid.ColumnSpacing = 6;
            statusTitleLabel = uilabel( app.StatusGrid, 'Text', 'Status', 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left');
            statusTitleLabel.Layout.Column = 1;
            app.StatusLamp = uilamp( app.StatusGrid, 'Color', app.ReadyStatusColor);
            app.StatusLamp.Layout.Column = 2;
            app.StatusLabel = uilabel( app.StatusGrid, 'Text', 'Ready', 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left');
            app.StatusLabel.Layout.Column = 3;

            %% RIGHT SIDE - PLOTS
            app.PlotGrid = uigridlayout( app.MainGrid, [2 1]);
            app.PlotGrid.Layout.Row = 1;
            app.PlotGrid.Layout.Column = 2;
            app.PlotGrid.RowHeight = {'1x', '1x'};
            app.PlotGrid.RowSpacing = 12;
            app.PlotGrid.Padding = [14 18 14 12];

            %% Temperature plot
            app.TemperatureAxes = uiaxes(app.PlotGrid);
            app.TemperatureAxes.Layout.Row = 1;
            app.TemperatureAxes.FontSize = 11;
            title( app.TemperatureAxes, 'Temperature Tracking', 'FontSize', 17, 'FontWeight', 'bold');
            ylabel( app.TemperatureAxes, 'Temperature [°C]', 'FontSize', 14, 'FontWeight', 'bold');
            % Both plots share the same time axis.
            grid(app.TemperatureAxes, 'on');
            box(app.TemperatureAxes, 'on');

            %% Heater plot
            app.ActuatorAxes = uiaxes(app.PlotGrid);
            app.ActuatorAxes.Layout.Row = 2;
            app.ActuatorAxes.FontSize = 11;
            title( app.ActuatorAxes, 'Heater Thermal Power', 'FontSize', 17, 'FontWeight', 'bold');
            xlabel( app.ActuatorAxes, 'Time [min]', 'FontSize', 14, 'FontWeight', 'bold');
            ylabel( app.ActuatorAxes, 'Thermal Power [W]', 'FontSize', 14, 'FontWeight', 'bold');
            grid(app.ActuatorAxes, 'on');
            box(app.ActuatorAxes, 'on');

            %% Initial control states
            % Apply controller-specific presentation after plot creation.
            app.updateDisturbanceControls();
            app.updatePacingControls();
        end

        %% UI HELPERS
        function field = addNumericRow( ~, parent, row, labelText, value, limits)
            rowGrid = uigridlayout( parent, [1 2]);
            rowGrid.Layout.Row = row;
            rowGrid.ColumnWidth = {130, '1x'};
            rowGrid.Padding = [0 0 0 0];
            rowGrid.ColumnSpacing = 5;
            uilabel( rowGrid, 'Text', labelText);
            field = uieditfield( rowGrid, 'numeric', 'Value', value, 'Limits', limits);
        end

        function field = addTextRow( ~, parent, row, labelText, value)
            rowGrid = uigridlayout( parent, [1 2]);
            rowGrid.Layout.Row = row;
            rowGrid.ColumnWidth = {130, '1x'};
            rowGrid.Padding = [0 0 0 0];
            rowGrid.ColumnSpacing = 5;
            uilabel( rowGrid, 'Text', labelText);
            field = uieditfield( rowGrid, 'text', 'Value', value);
        end

        function field = addDropDownRow( ~, parent, row, labelText, items, itemsData)
            rowGrid = uigridlayout( parent, [1 2]);
            rowGrid.Layout.Row = row;
            rowGrid.ColumnWidth = {130, '1x'};
            rowGrid.Padding = [0 0 0 0];
            rowGrid.ColumnSpacing = 5;
            uilabel( rowGrid, 'Text', labelText);
            field = uidropdown( rowGrid, 'Items', items, 'ItemsData', itemsData, 'Value', itemsData(1));
        end
    end

    %% PLOT INITIALIZATION
    methods (Access = private)
        function createPlotLines(app)
            colors = lines(4);

            %% Temperature axes
            hold(app.TemperatureAxes, 'on');
            app.ReferenceLines = cell(4,1);
            app.MeasurementLines = cell(4,1);
            % Draw measurements first so reference lines remain visible.
            for i = 1:4
                app.MeasurementLines{i} = plot( app.TemperatureAxes, NaN, NaN, '-', 'LineWidth', 1.6, ...
                    'Color', colors(i,:), 'DisplayName', sprintf('T%d', i));
            end
            for i = 1:4
                app.ReferenceLines{i} = plot( app.TemperatureAxes, NaN, NaN, '--', 'LineWidth', 0.9, ...
                    'Color', colors(i,:), 'DisplayName', sprintf('Tref%d', i));
            end
            temperatureHandles = [ app.ReferenceLines{:}, app.MeasurementLines{:}];
            try
                temperatureLegend = legend( temperatureHandles, { 'Tref1','Tref2','Tref3','Tref4', ...
                    'T1','T2','T3','T4' }, 'Location', 'southeast');
            catch
                temperatureLegend = legend( app.TemperatureAxes, 'show', 'Location', 'southeast');
            end
            temperatureLegend.NumColumns = 4;
            temperatureLegend.FontSize = 8;
            temperatureLegend.Box = 'on';
            temperatureLegend.Color = [1 1 1];
            try
                temperatureLegend.ItemTokenSize = [20 8];
            catch
            end

            %% Actuator axes
            hold(app.ActuatorAxes, 'on');
            app.HeatLines = cell(4,1);
            for i = 1:4
                app.HeatLines{i} = plot( app.ActuatorAxes, NaN, NaN, 'LineWidth', 1.25, ...
                    'Color', colors(i,:), 'DisplayName', sprintf('Q%d', i));
            end
            actuatorLegend = legend( app.ActuatorAxes, 'show', 'Location', 'southeast', 'NumColumns', 4);
            actuatorLegend.FontSize = 8;
            actuatorLegend.Box = 'on';
            actuatorLegend.Color = [1 1 1];
            try
                actuatorLegend.ItemTokenSize = [12 8];
            catch
            end
        end
    end

    %% LOAD / APPLY CONFIGURATION
    methods (Access = private)
        function loadConfigurationFromWorkspace(app)
            %% Controller
            if evalin( 'base', 'exist(''CONTROLLER_ID'',''var'')')
                app.ControllerDropDown.Value = evalin('base', 'CONTROLLER_ID');
            end

            %% Model type
            if evalin( 'base', 'exist(''MODEL_TYPE_ID'',''var'')')
                app.ModelTypeDropDown.Value = evalin('base', 'MODEL_TYPE_ID');
            end

            %% CFG
            if evalin( 'base', 'exist(''CFG'',''var'')')
                CFG = evalin('base', 'CFG');
                if isfield(CFG, 'reference') && isfield(CFG.reference, 'fourRooms')
                    refs = CFG.reference.fourRooms;
                    for i = 1:min(4,numel(refs))
                        app.ReferenceFields{i}.Value = refs(i);
                    end
                end
                if isfield(CFG, 'simulation')
                    if isfield(CFG.simulation, 'stopTime')
                        stopTimeSeconds = CFG.simulation.stopTime;
                        % Preserve compatibility with the previous stop-time default.
                        if abs(stopTimeSeconds - 2000) < 1e-9
                            stopTimeSeconds = app.DefaultStopTimeMinutes * 60;
                            CFG.simulation.stopTime = stopTimeSeconds;
                            assignin( 'base', 'CFG', CFG);
                            try
                                set_param( app.ModelName, 'StopTime', num2str(stopTimeSeconds));
                            catch
                            end
                        end
                        app.StopTimeField.Value = stopTimeSeconds / 60;
                    end
                    if isfield(CFG.simulation, 'pacing')
                        pacingValue = CFG.simulation.pacing;
                        pacingValue = min( max( pacingValue, app.PacingRateSlider.Limits(1)), ...
                            app.PacingRateSlider.Limits(2));
                        app.PacingRateSlider.Value = pacingValue;
                    end
                end
            end

            %% Environment
            if evalin( 'base', 'exist(''ENV'',''var'')')
                ENV = evalin('base', 'ENV');
                if isfield(ENV, 'T_a')
                    app.AmbientTemperatureField.Value = ENV.T_a;
                end
                if isfield(ENV, 'disturbance')
                    % Preserve compatibility with previous disturbance defaults.
                    hasOldDefaultDisturbance = isfield(ENV.disturbance, 'amplitude') && ...
                        isfield(ENV.disturbance, 'startTime') && isfield(ENV.disturbance, 'endTime') && ...
                        abs(ENV.disturbance.amplitude - 5) < 1e-9 && ...
                        abs(ENV.disturbance.startTime - 500) < 1e-9 && ...
                        abs(ENV.disturbance.endTime - 1000) < 1e-9;
                    if hasOldDefaultDisturbance
                        ENV.disturbance.amplitude = app.DefaultDisturbanceAmplitude;
                        ENV.disturbance.startTime = app.DefaultDisturbanceStartMinutes;
                        ENV.disturbance.endTime = app.DefaultDisturbanceEndMinutes;
                        assignin( 'base', 'ENV', ENV);
                    end
                    if isfield(ENV.disturbance, 'enabled')
                        app.DisturbanceEnabledCheckBox.Value = logical(ENV.disturbance.enabled);
                    end
                    if isfield(ENV.disturbance, 'amplitude')
                        app.DisturbanceAmplitudeField.Value = ENV.disturbance.amplitude;
                    end
                    if isfield(ENV.disturbance, 'startTime')
                        app.DisturbanceStartField.Value = ENV.disturbance.startTime;
                    end
                    if isfield(ENV.disturbance, 'endTime')
                        app.DisturbanceEndField.Value = ENV.disturbance.endTime;
                    end
                    if isfield(ENV.disturbance, 'roomMask')
                        mask = ENV.disturbance.roomMask(:);
                        for i = 1:4
                            if i <= numel(mask)
                                app.DisturbanceRoomCheckBoxes{i}.Value = logical(mask(i));
                            end
                        end
                        if numel(mask) >= 4
                            app.DisturbanceAllRoomsCheckBox.Value = all(mask(1:4) ~= 0);
                        end
                    end
                end
            end
            app.updateControllerPresentation();
            app.updateDisturbanceControls();
            app.updatePacingControls();
            % Generate the initial experiment name.
            app.updateExperimentSuggestion(true);
        end

        function autoApplyConfiguration(app)
            % Mark GUI changes and update the stopped model.
            app.ConfigurationDirty = true;
            if ~bdIsLoaded(app.ModelName)
                return;
            end
            try
                status = string( get_param( app.ModelName, 'SimulationStatus'));
            catch
                return;
            end
            if status ~= "stopped"
                app.setStatus( 'Changes pending', 'busy');
                return;
            end
            if app.IsBusy
                return;
            end
            app.setBusy(true);
            app.setStatus( 'Updating model...', 'busy');
            drawnow;
            try
                ok = app.applyConfiguration(false);
                if ok
                    app.ConfigurationDirty = false;
                    app.setStatus( 'Ready', 'ready');
                else
                    app.setStatus( 'Configuration pending', 'error');
                end
            catch ME
                app.setStatus( 'Configuration error', 'error');
                warning( 'MaIA_SDCI:AutoApplyConfiguration', '%s', ME.message);
            end
            app.setBusy(false);
            app.updateButtonStates(status);
        end

        function ok = applyConfiguration(app, showErrors)
            if nargin < 2
                showErrors = true;
            end
            ok = false;

            %% Simulation must be stopped
            try
                status = string( get_param( app.ModelName, 'SimulationStatus'));
            catch ME
                if showErrors
                    uialert( app.UIFigure, ME.message, 'Model Error');
                end
                return;
            end
            if status ~= "stopped"
                return;
            end

            %% Validate disturbance times entered in minutes
            if app.DisturbanceEnabledCheckBox.Value
                if app.DisturbanceEndField.Value <= app.DisturbanceStartField.Value
                    if showErrors
                        uialert( app.UIFigure, ['Disturbance end time must be greater ', ...
                             'than start time.'], 'Invalid Disturbance');
                    end
                    return;
                end
            end

            %% Required project variables
            requiredVars = {
                'CFG'
                'MODEL'
                'ENV'
            };
            for k = 1:numel(requiredVars)
                variableName = requiredVars{k};
                exists = evalin( 'base', sprintf( 'exist(''%s'',''var'')', variableName));
                if ~exists
                    if showErrors
                        uialert( app.UIFigure, ['Model initialization is incomplete. ', ...
                             'Missing variable: ', variableName], 'Initialization Error');
                    end
                    return;
                end
            end

            %% Controller and model type
            [controllerID, modelTypeID] = app.publishVariantSelections();

            %% Project configuration
            CFG = evalin('base', 'CFG');
            % Controller references.
            % ESC uses the isolated-room reference; other controllers use Rooms 1-4.
            if ~isfield(CFG, 'reference')
                CFG.reference = struct;
            end
            if isfield(CFG.reference, 'fourRooms') && numel(CFG.reference.fourRooms) >= 4
                fourRoomRefs = CFG.reference.fourRooms(:);
                fourRoomRefs = fourRoomRefs(1:4);
            else
                fourRoomRefs = zeros(4,1);
                for i = 1:4
                    fourRoomRefs(i) = app.ReferenceFields{i}.Value;
                end
            end
            if controllerID ~= 4
                for i = 1:4
                    fourRoomRefs(i) = app.ReferenceFields{i}.Value;
                end
                CFG.reference.fourRooms = fourRoomRefs;
            end
            if controllerID == 4
                singleRoomReference = app.ReferenceFields{1}.Value;
            elseif isfield(CFG.reference, 'singleRoom') && isscalar(CFG.reference.singleRoom) && ...
                    isfinite(CFG.reference.singleRoom)
                singleRoomReference = CFG.reference.singleRoom;
            else
                singleRoomReference = 22;
            end
            CFG.reference.singleRoom = singleRoomReference;
            stopTimeSeconds = app.StopTimeField.Value * 60;
            CFG.simulation.stopTime = stopTimeSeconds;
            CFG.simulation.pacing = app.PacingRateSlider.Value;
            CFG.simulation.pacingEnabled = app.PacingEnabledCheckBox.Value;
            assignin( 'base', 'CFG', CFG);

            %% Environment
            ENV = evalin('base', 'ENV');
            ENV.T_a = app.AmbientTemperatureField.Value;
            ENV.disturbance.enabled = app.DisturbanceEnabledCheckBox.Value;
            ENV.disturbance.startTime = app.DisturbanceStartField.Value;
            ENV.disturbance.endTime = app.DisturbanceEndField.Value;
            roomMask = zeros(4,1);
            for i = 1:4
                roomMask(i) = app.DisturbanceRoomCheckBoxes{i}.Value;
            end
            ENV.disturbance.roomMask = roomMask;
            ENV.disturbance.amplitude = app.DisturbanceAmplitudeField.Value;
            assignin( 'base', 'ENV', ENV);

            %% Model parameters
            set_param( app.ModelName, 'StopTime', num2str( stopTimeSeconds));
            if app.PacingEnabledCheckBox.Value
                set_param( app.ModelName, 'EnablePacing', 'on', 'PacingRate', num2str( ...
                    app.PacingRateSlider.Value));
            else
                set_param( app.ModelName, 'EnablePacing', 'off');
            end

            %% Signal logging
            app.setStatus( 'Configuring logging...', 'busy');
            drawnow;
            try
                configure_logging;
            catch ME
                if showErrors
                    uialert( app.UIFigure, ME.message, 'Logging Error');
                end
                return;
            end

            %% Compile/update model
            app.setStatus( 'Updating model...', 'busy');
            drawnow;
            try
                set_param( app.ModelName, 'SimulationCommand', 'update');
            catch ME
                if showErrors
                    uialert( app.UIFigure, ME.message, 'Model Update Error');
                end
                return;
            end
            ok = true;
            app.ConfigurationDirty = false;
            app.updateControllerPresentation();
            app.updatePlots();
        end
    end

    %% CONTROL CALLBACKS
    methods (Access = private)
        function onExperimentNameChanged(app)
            % Preserve a custom experiment name.
            suggestedName = app.getSuggestedExperimentName();
            currentName = string(app.ExperimentNameField.Value);
            app.ExperimentNameCustomized = currentName ~= string(suggestedName);
        end

        function onControllerChanged(app)
            % Update the GUI for the selected controller.
            app.updateControllerPresentation();
            app.updateExperimentSuggestion(false);
            app.clearPlots();
            app.autoApplyConfiguration();
            app.updatePlots();
        end

        function onModelTypeChanged(app)
            % Update the experiment name and selected backend.
            app.updateExperimentSuggestion(false);
            app.clearPlots();
            app.autoApplyConfiguration();
            app.updatePlots();
        end

        function onReferenceChanged(app)
            % Update reference lines and model configuration.
            app.updatePlots();
            app.autoApplyConfiguration();
        end

        function onDisturbanceEnabledChanged(app)
            app.updateDisturbanceControls();
            app.updateExperimentSuggestion(false);
            app.autoApplyConfiguration();
        end

        function onStopTimeChanged(app)
            app.updateExperimentSuggestion(false);
            app.autoApplyConfiguration();
        end

        function onDisturbanceRoomChanged(app)
            app.updateAllRoomsState();
            app.autoApplyConfiguration();
        end

        function onPacingEnabledChanged(app)
            app.updatePacingControls();
            app.autoApplyConfiguration();
        end
    end

    %% SIMULATION CONTROL
    methods (Access = private)
        function startSimulation(app)
            if app.IsBusy
                return;
            end
            status = app.getSimulationStatus();

            %% START also resumes a paused simulation
            if status == "paused"
                app.setBusy(true);
                app.setStatus( 'Resuming...', 'busy');
                drawnow;
                try
                    set_param( app.ModelName, 'SimulationCommand', 'continue');
                    status = app.getSimulationStatus();
                    app.setBusy(false);
                    app.updateButtonStates(status);
                    if status == "running"
                        app.setStatus( 'Running', 'running');
                    else
                        app.setStatus( 'Paused', 'paused');
                    end
                catch ME
                    app.setBusy(false);
                    app.updateButtonStates("paused");
                    app.setStatus( 'Resume error', 'error');
                    uialert( app.UIFigure, ME.message, 'Simulation Error');
                end
                return;
            end
            if status ~= "stopped"
                return;
            end

            %% Variant controls
            % Re-publish variant controls before each run.
            app.publishVariantSelections();

            %% Start preparation
            app.setBusy(true);
            app.StopRequested = false;
            app.setStatus( 'Configuring...', 'busy');
            drawnow;
            try

                %% Configuration
                % Apply pending configuration changes before starting.
                if app.ConfigurationDirty
                    if ~app.applyConfiguration(true)
                        app.setBusy(false);
                        app.updateButtonStates("stopped");
                        app.setStatus( 'Configuration pending', 'error');
                        return;
                    end
                end

                %% Prepare new run
                app.clearPlots();
                app.CurrentRunID = NaN;
                app.LastFinalizedRunID = NaN;
                app.SimulationWasActive = true;
                app.bringToFront();

                %% Start simulation
                app.setStatus( 'Starting simulation...', 'busy');
                drawnow;
                started = app.requestSimulationStart();
                status = app.getSimulationStatus();
                app.setBusy(false);
                app.updateButtonStates(status);
                if status == "running"
                    app.setStatus( 'Running', 'running');
                elseif status == "paused"
                    app.setStatus( 'Paused', 'paused');
                elseif started
                    % Handle runs that finish before the GUI detects the running state.
                    app.setStatus( 'Finished', 'ready');
                else
                    app.SimulationWasActive = false;
                    app.setStatus( 'Start failed', 'error');
                    uialert( app.UIFigure, ['The simulation did not enter the running state. ', ...
                         'Please review the model diagnostics.'], 'Simulation Start Error');
                end
            catch ME
                assignin( 'base', 'MaIA_SDCI_RUN_FROM_GUI', false);
                app.SimulationWasActive = false;
                app.setBusy(false);
                app.updateButtonStates("stopped");
                app.setStatus( 'Simulation error', 'error');
                uialert( app.UIFigure, ME.message, 'Simulation Error');
            end
        end

        function started = requestSimulationStart(app)
            started = false;
            % Retry once if a paced simulation does not start immediately.
            stopTimeSeconds = app.StopTimeField.Value * 60;
            if app.PacingEnabledCheckBox.Value
                expectedWallTime = stopTimeSeconds / max(app.PacingRateSlider.Value, eps);
            else
                expectedWallTime = 0;
            end
            maximumAttempts = 1;
            if app.PacingEnabledCheckBox.Value && expectedWallTime > 0.75
                maximumAttempts = 2;
            end
            for attempt = 1:maximumAttempts
                % Ensure variant controls exist before model evaluation.
                app.publishVariantSelections();
                assignin( 'base', 'MaIA_SDCI_RUN_FROM_GUI', true);
                set_param( app.ModelName, 'SimulationCommand', 'start');
                drawnow;
                pause(0.12);
                status = app.getSimulationStatus();
                if status == "running" || status == "paused"
                    started = true;
                    return;
                end
                if ~app.PacingEnabledCheckBox.Value || expectedWallTime <= 0.75
                    % Short runs may finish before the status check.
                    started = true;
                    return;
                end
                if attempt < maximumAttempts
                    app.setStatus( 'Starting simulation...', 'busy');
                    drawnow;
                    pause(0.08);
                end
            end
        end

        function pauseSimulation(app)
            if app.IsBusy
                return;
            end
            status = app.getSimulationStatus();
            if status == "running"
                app.setBusy(true);
                app.setStatus( 'Pausing...', 'busy');
                drawnow;
                try
                    set_param( app.ModelName, 'SimulationCommand', 'pause');
                    app.setBusy(false);
                    app.updateButtonStates("paused");
                    app.setStatus( 'Paused', 'paused');
                catch ME
                    app.setBusy(false);
                    app.updateButtonStates(status);
                    app.setStatus( 'Pause error', 'error');
                    uialert( app.UIFigure, ME.message, 'Simulation Error');
                end
            end
        end

        function stopSimulation(app)
            if app.IsBusy
                return;
            end
            status = app.getSimulationStatus();
            if status == "running" || status == "paused"
                app.setBusy(true);
                app.StopRequested = true;
                app.setStatus( 'Stopping...', 'busy');
                drawnow;
                try
                    set_param( app.ModelName, 'SimulationCommand', 'stop');
                    app.setBusy(false);
                    app.updateButtonStates("stopped");
                    app.setStatus( 'Stopped', 'ready');
                catch ME
                    app.StopRequested = false;
                    app.setBusy(false);
                    app.updateButtonStates(status);
                    app.setStatus( 'Stop error', 'error');
                    uialert( app.UIFigure, ME.message, 'Simulation Error');
                end
            end
        end

        function status = getSimulationStatus(app)
            try
                status = string( get_param( app.ModelName, 'SimulationStatus'));
            catch
                status = "stopped";
            end
        end
    end

    %% LIVE UPDATE TIMER
    methods (Access = private)
        function createUpdateTimer(app)
            app.UpdateTimer = timer( 'ExecutionMode', 'fixedSpacing', 'Period', app.UpdatePeriod, ...
                'BusyMode', 'drop', 'TimerFcn', @(~,~) app.timerUpdate());
            start(app.UpdateTimer);
        end

        function timerUpdate(app)
            if isempty(app.UIFigure) || ~isvalid(app.UIFigure)
                return;
            end
            if ~bdIsLoaded(app.ModelName)
                return;
            end
            try
                status = string( get_param( app.ModelName, 'SimulationStatus'));
            catch
                return;
            end
            app.updateButtonStates(status);
            if status == "running" || status == "paused"
                app.SimulationWasActive = true;
                if ~app.IsBusy
                    if status == "running"
                        app.setStatus( 'Running', 'running');
                    else
                        app.setStatus( 'Paused', 'paused');
                    end
                end
                app.refreshFromSDI();
            elseif status == "stopped"
                if app.SimulationWasActive
                    app.refreshFromSDI();
                    app.finalizeRun();
                    app.SimulationWasActive = false;
                    if app.StopRequested
                        app.setStatus( 'Stopped', 'ready');
                    else
                        app.setStatus( 'Finished', 'ready');
                    end
                    app.StopRequested = false;
                end
            end
        end
    end

    %% SDI DATA ACCESS
    methods (Access = private)
        function refreshFromSDI(app)
            try
                runObj = Simulink.sdi.getCurrentSimulationRun( app.ModelName);
            catch
                return;
            end
            if isempty(runObj)
                return;
            end
            runID = runObj.ID;

            %% Detect a new simulation
            if isnan(app.CurrentRunID) || app.CurrentRunID ~= runID
                app.CurrentRunID = runID;
                app.LatestData = app.emptyDataStruct();
                app.LastFinalizedRunID = NaN;
                app.clearPlotLines();
            end

            %% Reference
            try
                [t, y] = app.readSignal( runObj, 'T_ref');
                if ~isempty(t)
                    app.LatestData.TRefTime = t;
                    app.LatestData.TRef = app.ensureFourColumns(y);
                end
            catch
            end

            %% Measurement
            try
                [t, y] = app.readSignal( runObj, 'T_meas');
                if ~isempty(t)
                    app.LatestData.TMeasTime = t;
                    app.LatestData.TMeas = app.ensureFourColumns(y);
                end
            catch
            end

            %% Thermal power
            try
                [t, y] = app.readSignal( runObj, 'Q_heat');
                if ~isempty(t)
                    app.LatestData.QHeatTime = t;
                    app.LatestData.QHeat = app.ensureFourColumns(y);
                end
            catch
            end

            %% Update plots
            app.updatePlots();
        end

        function [time, data] = readSignal(app, runObj, signalName)
            signals = getSignalsByName( runObj, signalName);
            if isempty(signals)
                time = [];
                data = [];
                return;
            end
            signal = signals(1);
            values = signal.Values;
            if ~isa(values, 'timeseries')
                time = [];
                data = [];
                return;
            end
            time = double(values.Time(:));
            data = app.normalizeSignalData( values.Data, numel(time));
        end

        function data = normalizeSignalData(~, rawData, numberOfTimes)
            if isempty(rawData) || numberOfTimes == 0
                data = [];
                return;
            end
            rawData = squeeze(rawData);
            if isvector(rawData)
                if numel(rawData) == numberOfTimes
                    data = reshape( rawData, numberOfTimes, 1);
                    return;
                end
            end
            if size(rawData,1) == numberOfTimes
                data = rawData;
                return;
            end
            if size(rawData,2) == numberOfTimes
                data = rawData.';
                return;
            end
            if mod( numel(rawData), numberOfTimes) == 0
                data = reshape( rawData, [], numberOfTimes).';
                return;
            end
            data = [];
        end

        function data = ensureFourColumns(~, data)
            if isempty(data)
                return;
            end
            numberOfColumns = size(data,2);
            if numberOfColumns < 4
                data(:,numberOfColumns+1:4) = NaN;
            elseif numberOfColumns > 4
                data = data(:,1:4);
            end
        end
    end

    %% LIVE PLOTS
    methods (Access = private)
        function updatePlots(app)
            controllerID = app.ControllerDropDown.Value;
            if controllerID == 4
                activeRooms = 1;
            else
                activeRooms = 1:4;
            end

            %% Visibility
            for room = 1:4
                if ismember(room, activeRooms)
                    visibility = 'on';
                else
                    visibility = 'off';
                end
                app.ReferenceLines{room}.Visible = visibility;
                app.MeasurementLines{room}.Visible = visibility;
                app.HeatLines{room}.Visible = visibility;
            end

            %% Visible time range in minutes
            currentTimeSeconds = app.getLatestSimulationTime();
            currentTimeMinutes = currentTimeSeconds / 60;
            plannedStopMinutes = app.StopTimeField.Value;
            if ~isfinite(plannedStopMinutes) || plannedStopMinutes <= 0
                plannedStopMinutes = 1;
            end
            plotEndMinutes = max( plannedStopMinutes, currentTimeMinutes);
            plotEndMinutes = max(1, plotEndMinutes);

            %% Horizontal reference lines
            % ESC uses the isolated-room reference; other controllers use GUI references.
            for room = activeRooms
                if controllerID == 4
                    referenceValue = app.getSingleRoomReference();
                else
                    referenceValue = app.ReferenceFields{room}.Value;
                end
                app.ReferenceLines{room}.XData = [0 plotEndMinutes];
                app.ReferenceLines{room}.YData = [referenceValue referenceValue];
            end

            %% Measured temperature
            if ~isempty(app.LatestData.TMeasTime)
                [t, y] = app.decimateForDisplay( app.LatestData.TMeasTime, app.LatestData.TMeas);
                tMinutes = t / 60;
                for room = activeRooms
                    app.MeasurementLines{room}.XData = tMinutes;
                    app.MeasurementLines{room}.YData = y(:,room);
                end
            end

            %% Heater power
            if ~isempty(app.LatestData.QHeatTime)
                [t, y] = app.decimateForDisplay( app.LatestData.QHeatTime, app.LatestData.QHeat);
                tMinutes = t / 60;
                for room = activeRooms
                    app.HeatLines{room}.XData = tMinutes;
                    app.HeatLines{room}.YData = y(:,room);
                end
            end

            %% Shared time axis
            xlim( app.TemperatureAxes, [0 plotEndMinutes]);
            xlim( app.ActuatorAxes, [0 plotEndMinutes]);

            %% Automatic Y-axis limits
            app.updateTemperatureYLimits( activeRooms);
            app.updateActuatorYLimits( activeRooms);
            drawnow limitrate nocallbacks;
        end

        function updateTemperatureYLimits( app, activeRooms)
            values = [];

            %% Include active setpoints
            controllerID = app.ControllerDropDown.Value;
            for room = activeRooms
                if controllerID == 4
                    referenceValue = app.getSingleRoomReference();
                else
                    referenceValue = app.ReferenceFields{room}.Value;
                end
                if isfinite(referenceValue)
                    values(end+1,1) = referenceValue; %#ok<AGROW>
                end
            end

            %% Include measured temperatures
            if ~isempty(app.LatestData.TMeas)
                measuredValues = app.LatestData.TMeas(:,activeRooms);
                values = [ values; measuredValues(:)]; %#ok<AGROW>
            end
            values = values(isfinite(values));
            if isempty(values)
                return;
            end
            yMinimum = min(values);
            yMaximum = max(values);
            span = yMaximum - yMinimum;
            margin = max(0.5, 0.06 * max(span, 1));
            ylim( app.TemperatureAxes, [ yMinimum - margin, yMaximum + margin ]);
        end

        function updateActuatorYLimits( app, activeRooms)
            if isempty(app.LatestData.QHeat)
                ylim( app.ActuatorAxes, [-100 2600]);
                return;
            end
            actuatorValues = app.LatestData.QHeat(:,activeRooms);
            values = actuatorValues(:);
            values = values(isfinite(values));
            if isempty(values)
                return;
            end
            yMinimum = min([0; values]);
            yMaximum = max([0; values]);
            span = yMaximum - yMinimum;
            margin = max(50, 0.04 * max(span, 1));
            ylim( app.ActuatorAxes, [ yMinimum - margin, yMaximum + margin ]);
        end

        function [timeOut, dataOut] = decimateForDisplay(app, timeIn, dataIn)
            numberOfPoints = numel(timeIn);
            if numberOfPoints <= app.MaxPlotPoints
                timeOut = timeIn;
                dataOut = dataIn;
                return;
            end
            indices = unique( round( linspace( 1, numberOfPoints, app.MaxPlotPoints)));
            timeOut = timeIn(indices);
            dataOut = dataIn(indices,:);
        end

        function clearPlotLines(app)
            for room = 1:4
                app.ReferenceLines{room}.XData = NaN;
                app.ReferenceLines{room}.YData = NaN;
                app.MeasurementLines{room}.XData = NaN;
                app.MeasurementLines{room}.YData = NaN;
                app.HeatLines{room}.XData = NaN;
                app.HeatLines{room}.YData = NaN;
            end
        end

        function clearPlots(app)
            app.LatestData = app.emptyDataStruct();
            app.LastRun = struct;
            app.LastFinalizedRunID = NaN;
            app.clearPlotLines();
            xlim( app.TemperatureAxes, 'auto');
            ylim( app.TemperatureAxes, 'auto');
            xlim( app.ActuatorAxes, 'auto');
            ylim( app.ActuatorAxes, 'auto');
        end
    end

    %% SIMULATION TIME
    methods (Access = private)
        function currentTime = getLatestSimulationTime(app)
            currentTime = 0;
            candidates = [];
            if ~isempty(app.LatestData.TRefTime)
                candidates(end+1) = app.LatestData.TRefTime(end);
            end
            if ~isempty(app.LatestData.TMeasTime)
                candidates(end+1) = app.LatestData.TMeasTime(end);
            end
            if ~isempty(app.LatestData.QHeatTime)
                candidates(end+1) = app.LatestData.QHeatTime(end);
            end
            if ~isempty(candidates)
                currentTime = max(candidates);
                return;
            end
            try
                currentTime = str2double( get_param( app.ModelName, 'SimulationTime'));
                if isnan(currentTime)
                    currentTime = 0;
                end
            catch
                currentTime = 0;
            end
        end
    end

    %% FINALIZE RUN
    methods (Access = private)
        function finalizeRun(app)
            if isnan(app.CurrentRunID)
                return;
            end
            if ~isnan( app.LastFinalizedRunID) && app.LastFinalizedRunID == app.CurrentRunID
                return;
            end
            app.refreshFromSDI();
            if isempty( app.LatestData.TMeasTime)
                return;
            end
            % Keep only the data required to save metrics.
            RUN = struct;
            RUN.controllerID = app.ControllerDropDown.Value;
            RUN.modelTypeID = app.ModelTypeDropDown.Value;
            RUN.experimentName = app.ExperimentNameField.Value;
            RUN.timestamp = datetime('now');
            RUN.sdiRunID = app.CurrentRunID;
            RUN.data = app.LatestData;
            app.LastRun = RUN;
            app.LastFinalizedRunID = app.CurrentRunID;
        end
    end

    %% SIGNAL ALIGNMENT
    methods (Access = private)
        function reference = resampleReference(app, targetTime)
            reference = NaN( numel(targetTime), 4);
            if isempty( app.LatestData.TRefTime)
                return;
            end
            tRef = app.LatestData.TRefTime;
            yRef = app.LatestData.TRef;
            for room = 1:4
                if numel(tRef) == 1
                    reference(:,room) = yRef(1,room);
                else
                    reference(:,room) = interp1( tRef, yRef(:,room), targetTime, 'previous', 'extrap');
                end
            end
        end
    end

    %% SAVE RESULTS
    methods (Access = private)
        function saveMetrics(app)
            %% Finalize current stopped run if needed
            try
                status = string( get_param( app.ModelName, 'SimulationStatus'));
            catch
                status = "stopped";
            end
            if status ~= "stopped"
                uialert( app.UIFigure, ['Stop or complete the simulation before ', 'saving the metrics.'], ...
                    'Simulation Active');
                return;
            end
            if isempty(fieldnames(app.LastRun))
                app.refreshFromSDI();
                app.finalizeRun();
            end
            if isempty(fieldnames(app.LastRun))
                uialert( app.UIFigure, 'No completed simulation is available.', 'No Results');
                return;
            end
            RUN = app.LastRun;
            app.setBusy(true);
            app.setStatus( 'Saving metrics...', 'busy');
            drawnow;

            %% Prepare aligned signals
            tTemperature = RUN.data.TMeasTime;
            T_meas = RUN.data.TMeas;
            T_ref = app.resampleReference( tTemperature);
            tPower = RUN.data.QHeatTime;
            Q_heat = RUN.data.QHeat;

            %% Compute individual metrics using the utility
            try
                metricsTable = compute_metrics( tTemperature, T_ref, T_meas, tPower, Q_heat, ...
                    RUN.controllerID);
            catch ME
                app.setBusy(false);
                app.setStatus( 'Metrics error', 'error');
                uialert( app.UIFigure, ME.message, 'Metrics Error');
                return;
            end

            %% Results folder
            resultsFolder = app.getResultsRootFolder();

            %% Save only CSV + PNG using the utility
            try
                savedFiles = save_results( metricsTable, app.UIFigure, app.ExperimentNameField.Value, ...
                    resultsFolder);
            catch ME
                app.setBusy(false);
                app.setStatus( 'Save error', 'error');
                uialert( app.UIFigure, ME.message, 'Save Error');
                return;
            end

            %% Confirmation
            app.setBusy(false);
            app.setStatus( 'Metrics saved', 'ready');
            [~, csvName, csvExt] = fileparts(savedFiles.csv);
            [~, pngName, pngExt] = fileparts(savedFiles.png);
            message = sprintf( ['Results saved in:\n%s\n\n' '%s%s\n%s%s'], resultsFolder, csvName, csvExt, ...
                pngName, pngExt);
            uialert( app.UIFigure, message, 'Metrics Saved', 'Icon', 'success');
        end

        function folder = getResultsRootFolder(app)
            if evalin( 'base', 'exist(''PROJECT'',''var'')')
                PROJECT = evalin( 'base', 'PROJECT');
                folder = PROJECT.resultsFolder;
            else
                projectRoot = fileparts( which( [app.ModelName '.slx']));
                folder = fullfile( projectRoot, 'results');
            end
            if ~isfolder(folder)
                mkdir(folder);
            end
        end
    end

    %% EXPERIMENT NAME
    methods (Access = private)
        function updateExperimentSuggestion(app, forceUpdate)
            if nargin < 2
                forceUpdate = false;
            end
            if ~forceUpdate && app.ExperimentNameCustomized
                return;
            end
            app.ExperimentNameField.Value = app.getSuggestedExperimentName();
            app.ExperimentNameCustomized = false;
        end

        function experimentName = getSuggestedExperimentName(app)
            controllerID = app.ControllerDropDown.Value;
            switch controllerID
                case 1
                    controllerName = "ONOFF";
                case 2
                    controllerName = "FUZZY";
                case 3
                    controllerName = "MPC";
                case 4
                    controllerName = "ESC";
                case 5
                    controllerName = "REPLICATOR";
                otherwise
                    controllerName = "CTRL";
            end
            modelTypeID = app.ModelTypeDropDown.Value;
            switch modelTypeID
                case 1
                    modelTypeName = "BLOCK";
                case 2
                    modelTypeName = "SIMSCAPE";
                otherwise
                    modelTypeName = "MODEL";
            end
            if app.DisturbanceEnabledCheckBox.Value
                disturbanceName = "DIST";
            else
                disturbanceName = "NOM";
            end
            stopMinutes = app.StopTimeField.Value;
            if abs(stopMinutes - round(stopMinutes)) < 1e-9
                stopText = sprintf( '%dmin', round(stopMinutes));
            else
                stopText = sprintf( '%.2fmin', stopMinutes);
                stopText = regexprep( stopText, '0+min$', 'min');
                stopText = strrep( stopText, '.', 'p');
            end
            experimentName = char( controllerName + "_" + modelTypeName + "_" + disturbanceName + "_" + ...
                string(stopText));
        end
    end

    %% CONTROLLER-SPECIFIC GUI PRESENTATION
    methods (Access = private)
        function updateControllerPresentation(app)
            controllerID = app.ControllerDropDown.Value;
            if controllerID == 4

                %% ESC - isolated fifth room
                singleRoomReference = app.getSingleRoomReference();
                app.ReferenceTitleLabel.Text = 'ESC Reference [°C]';
                app.ReferenceRoomLabels{1}.Text = 'Room 5';
                app.ReferenceRoomLabels{1}.Visible = 'on';
                app.ReferenceFields{1}.Visible = 'on';
                app.ReferenceFields{1}.Value = singleRoomReference;
                app.ReferenceFields{1}.Enable = 'on';

                app.DisturbanceAllRoomsCheckBox.Visible = 'off';
                app.DisturbanceRoomCheckBoxes{1}.Text = '5';
                app.DisturbanceRoomCheckBoxes{1}.Visible = 'on';
                for i = 2:4
                    app.DisturbanceRoomCheckBoxes{i}.Visible = 'off';
                end

                for i = 2:4
                    app.ReferenceRoomLabels{i}.Visible = 'off';
                    app.ReferenceFields{i}.Visible = 'off';
                    app.ReferenceFields{i}.Enable = 'off';
                end
            else

                %% Four-room controllers
                app.ReferenceTitleLabel.Text = 'Temperature References [°C]';

                app.DisturbanceAllRoomsCheckBox.Visible = 'on';
                for i = 1:4
                    app.DisturbanceRoomCheckBoxes{i}.Text = sprintf('%d', i);
                    app.DisturbanceRoomCheckBoxes{i}.Visible = 'on';
                end

                fourRoomRefs = [];
                if evalin( 'base', 'exist(''CFG'',''var'')')
                    CFG = evalin('base', 'CFG');
                    if isfield(CFG, 'reference') && isfield(CFG.reference, 'fourRooms') && ...
                            numel(CFG.reference.fourRooms) >= 4
                        fourRoomRefs = CFG.reference.fourRooms(:);
                    end
                end
                for i = 1:4
                    app.ReferenceRoomLabels{i}.Text = sprintf('Room %d', i);
                    app.ReferenceRoomLabels{i}.Visible = 'on';
                    app.ReferenceFields{i}.Visible = 'on';
                    app.ReferenceFields{i}.Enable = 'on';
                    if ~isempty(fourRoomRefs)
                        app.ReferenceFields{i}.Value = fourRoomRefs(i);
                    end
                end
            end
            app.updatePlotLegends();
        end

        function referenceValue = getSingleRoomReference(~)
            referenceValue = 22;
            if evalin( 'base', 'exist(''CFG'',''var'')')
                CFG = evalin('base', 'CFG');
                if isfield(CFG, 'reference') && isfield(CFG.reference, 'singleRoom') && ...
                        isscalar(CFG.reference.singleRoom) && isfinite(CFG.reference.singleRoom)
                    referenceValue = CFG.reference.singleRoom;
                    return;
                end
            end
        end

        function updatePlotLegends(app)
            % Update line visibility after plot handles are created.
            if isempty(app.ReferenceLines) || isempty(app.MeasurementLines) || isempty(app.HeatLines)
                return;
            end
            controllerID = app.ControllerDropDown.Value;
            legend(app.TemperatureAxes, 'off');
            legend(app.ActuatorAxes, 'off');
            if controllerID == 4

                %% ESC - isolated Room 5 only
                app.ReferenceLines{1}.DisplayName = 'Tref5';
                app.MeasurementLines{1}.DisplayName = 'T5';
                app.HeatLines{1}.DisplayName = 'Q5';
                for i = 1:4
                    if i == 1
                        app.ReferenceLines{i}.HandleVisibility = 'on';
                        app.MeasurementLines{i}.HandleVisibility = 'on';
                        app.HeatLines{i}.HandleVisibility = 'on';
                    else
                        app.ReferenceLines{i}.HandleVisibility = 'off';
                        app.MeasurementLines{i}.HandleVisibility = 'off';
                        app.HeatLines{i}.HandleVisibility = 'off';
                    end
                end
                temperatureHandles = [ app.ReferenceLines{1}, app.MeasurementLines{1}];
                try
                    temperatureLegend = legend( temperatureHandles, {'Tref5','T5'}, 'Location', 'southeast');
                catch
                    temperatureLegend = legend( app.TemperatureAxes, 'show', 'Location', 'southeast');
                end
                try
                    actuatorLegend = legend( app.HeatLines{1}, {'Q5'}, 'Location', 'southeast');
                catch
                    actuatorLegend = legend( app.ActuatorAxes, 'show', 'Location', 'southeast');
                end
                temperatureLegend.NumColumns = 2;
                actuatorLegend.NumColumns = 1;
            else

                %% Four-room controllers
                for i = 1:4
                    app.ReferenceLines{i}.DisplayName = sprintf('Tref%d', i);
                    app.MeasurementLines{i}.DisplayName = sprintf('T%d', i);
                    app.HeatLines{i}.DisplayName = sprintf('Q%d', i);
                    app.ReferenceLines{i}.HandleVisibility = 'on';
                    app.MeasurementLines{i}.HandleVisibility = 'on';
                    app.HeatLines{i}.HandleVisibility = 'on';
                end
                temperatureHandles = [ app.ReferenceLines{:}, app.MeasurementLines{:}];
                temperatureLabels = { 'Tref1','Tref2','Tref3','Tref4', 'T1','T2','T3','T4'};
                actuatorHandles = [app.HeatLines{:}];
                actuatorLabels = {'Q1','Q2','Q3','Q4'};
                try
                    temperatureLegend = legend( temperatureHandles, temperatureLabels, ...
                        'Location', 'southeast');
                catch
                    temperatureLegend = legend( app.TemperatureAxes, 'show', 'Location', 'southeast');
                end
                try
                    actuatorLegend = legend( actuatorHandles, actuatorLabels, 'Location', 'southeast');
                catch
                    actuatorLegend = legend( app.ActuatorAxes, 'show', 'Location', 'southeast');
                end
                temperatureLegend.NumColumns = 4;
                actuatorLegend.NumColumns = 4;
            end
            temperatureLegend.FontSize = 8;
            temperatureLegend.Box = 'on';
            temperatureLegend.Color = [1 1 1];
            actuatorLegend.FontSize = 8;
            actuatorLegend.Box = 'on';
            actuatorLegend.Color = [1 1 1];
            try
                temperatureLegend.ItemTokenSize = [20 8];
            catch
            end
            try
                actuatorLegend.ItemTokenSize = [12 8];
            catch
            end
        end
    end

    %% CONTROL STATES
    methods (Access = private)
        function updateButtonStates(app, status)
            %% Default colors
            app.StartButton.BackgroundColor = app.DefaultButtonColor;
            app.PauseButton.BackgroundColor = app.DefaultButtonColor;
            app.StopButton.BackgroundColor = app.DefaultButtonColor;

            %% Busy state
            if app.IsBusy
                app.StartButton.Enable = 'off';
                app.PauseButton.Enable = 'off';
                app.StopButton.Enable = 'off';
                return;
            end

            %% Simulation state
            if status == "running"
                app.StartButton.Enable = 'off';
                app.PauseButton.Enable = 'on';
                app.StopButton.Enable = 'on';
                app.StartButton.BackgroundColor = app.StartActiveColor;
            elseif status == "paused"
                app.StartButton.Enable = 'on';
                app.PauseButton.Enable = 'off';
                app.StopButton.Enable = 'on';
                app.PauseButton.BackgroundColor = app.PauseActiveColor;
            else
                app.StartButton.Enable = 'on';
                app.PauseButton.Enable = 'off';
                app.StopButton.Enable = 'off';
                app.StopButton.BackgroundColor = app.StopActiveColor;
            end
        end

        function [controllerID, modelTypeID] = publishVariantSelections(app)
            controllerID = app.ControllerDropDown.Value;
            modelTypeID = app.ModelTypeDropDown.Value;
            % Publish variant controls required by Simulink.
            assignin( 'base', 'CONTROLLER_ID', controllerID);
            assignin( 'base', 'MODEL_TYPE_ID', modelTypeID);
        end

        function setBusy(app, busy)
            app.IsBusy = logical(busy);
            if app.IsBusy
                state = 'off';
            else
                state = 'on';
            end

            %% Busy controls
            % Prevent configuration changes while the model is being updated.
            app.ControllerDropDown.Enable = state;
            app.ModelTypeDropDown.Enable = state;
            app.AmbientTemperatureField.Enable = state;
            app.DisturbanceEnabledCheckBox.Enable = state;
            app.StopTimeField.Enable = state;
            app.PacingEnabledCheckBox.Enable = state;
            app.ClearButton.Enable = state;
            app.SaveMetricsButton.Enable = state;
            for i = 1:4
                app.ReferenceFields{i}.Enable = state;
            end
            if app.IsBusy
                app.DisturbanceAmplitudeField.Enable = 'off';
                app.DisturbanceStartField.Enable = 'off';
                app.DisturbanceEndField.Enable = 'off';
                app.DisturbanceAllRoomsCheckBox.Enable = 'off';
                app.PacingRateSlider.Enable = 'off';
                for i = 1:4
                    app.DisturbanceRoomCheckBoxes{i}.Enable = 'off';
                end
            else
                app.updateDisturbanceControls();
                app.updatePacingControls();
            end
            status = app.getSimulationStatus();
            app.updateButtonStates(status);
        end

        function setStatus(app, textValue, state)
            if isempty(app.StatusLabel) || ~isvalid(app.StatusLabel)
                return;
            end
            if nargin < 3
                state = 'ready';
            end
            app.StatusLabel.Text = char(textValue);
            switch lower(string(state))
                case "busy"
                    color = app.BusyStatusColor;
                case "running"
                    color = app.RunningStatusColor;
                case "paused"
                    color = app.PausedStatusColor;
                case "error"
                    color = app.ErrorStatusColor;
                otherwise
                    color = app.ReadyStatusColor;
            end
            if ~isempty(app.StatusLamp) && isvalid(app.StatusLamp)
                app.StatusLamp.Color = color;
            end
            drawnow limitrate;
        end

        function updateDisturbanceControls(app)
            if app.DisturbanceEnabledCheckBox.Value
                state = 'on';
            else
                state = 'off';
            end
            app.DisturbanceAmplitudeField.Enable = state;
            app.DisturbanceStartField.Enable = state;
            app.DisturbanceEndField.Enable = state;
            app.DisturbanceAllRoomsCheckBox.Enable = state;
            for i = 1:4
                app.DisturbanceRoomCheckBoxes{i}.Enable = state;
            end
        end

        function setAllDisturbanceRooms(app)
            value = app.DisturbanceAllRoomsCheckBox.Value;
            for i = 1:4
                app.DisturbanceRoomCheckBoxes{i}.Value = value;
            end
            app.autoApplyConfiguration();
        end

        function updateAllRoomsState(app)
            values = false(4,1);
            for i = 1:4
                values(i) = app.DisturbanceRoomCheckBoxes{i}.Value;
            end
            app.DisturbanceAllRoomsCheckBox.Value = all(values);
        end

        function updatePacingControls(app)
            if app.PacingEnabledCheckBox.Value
                app.PacingRateSlider.Enable = 'on';
            else
                app.PacingRateSlider.Enable = 'off';
            end
        end
    end

    %% DATA STRUCTURE
    methods (Access = private)
        function data = emptyDataStruct(~)
            data = struct;
            data.TRefTime = [];
            data.TRef = [];
            data.TMeasTime = [];
            data.TMeas = [];
            data.QHeatTime = [];
            data.QHeat = [];
        end
    end

    %% CLOSE APPLICATION
    methods (Access = private)
        function closeApplication(app)
            %% Timer
            if ~isempty(app.UpdateTimer)
                try
                    stop(app.UpdateTimer);
                catch
                end
                try
                    delete(app.UpdateTimer);
                catch
                end
            end

            %% Singleton reference
            if isappdata( 0, app.AppKey)
                storedApp = getappdata( 0, app.AppKey);
                if isequal(storedApp, app)
                    rmappdata( 0, app.AppKey);
                end
            end

            %% Figure
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                app.UIFigure.CloseRequestFcn = [];
                delete(app.UIFigure);
            end
        end
    end
end
