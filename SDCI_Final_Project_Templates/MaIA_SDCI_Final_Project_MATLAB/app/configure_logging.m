function configure_logging

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Configures the signals used by the GUI and post-processing utilities.


%% PROJECT CONFIGURATION

if ~evalin('base', 'exist(''CFG'',''var'')')
    error('MaIA_SDCI:Logging:MissingConfiguration', ...
        ['CFG was not found in the Base Workspace. ' ...
         'Load the project configuration first.']);
end

CFG = evalin('base', 'CFG');


%% MODEL

modelName = CFG.modelName;

if ~bdIsLoaded(modelName)
    load_system(modelName);
end

simulationStatus = string(get_param(modelName, 'SimulationStatus'));

if simulationStatus ~= "stopped"
    error('MaIA_SDCI:Logging:ModelRunning', ...
        ['Signal logging must be configured while the model is ' ...
         'stopped. Current status: %s.'], ...
        simulationStatus);
end


%% LOGGING

if ~CFG.logging.enabled
    set_param(modelName, 'SignalLogging', 'off');
    fprintf('GUI signal logging disabled.\n');
    return;
end

set_param(modelName, ...
    'SignalLogging', 'on', ...
    'SignalLoggingName', 'logsout');


%% SIGNAL SOURCES

actuatorBlockName = 'Actuator';

signalSources = struct;
signalSources.T_ref = 'Reference';
signalSources.T_meas = 'Sensors';
signalSources.Q_heat = actuatorBlockName;


%% REQUIRED SIGNALS

requiredSignals = CFG.logging.signals;

for k = 1:numel(requiredSignals)

    signalName = requiredSignals{k};

    % Check that the signal is defined in the source map.
    if ~isfield(signalSources, signalName)
        error('MaIA_SDCI:Logging:UnknownSignal', ...
            'Signal "%s" is not defined in the logging source map.', ...
            signalName);
    end

    blockName = signalSources.(signalName);
    blockPath = [modelName '/' blockName];

    % Check that the source block exists.
    if getSimulinkBlockHandle(blockPath) == -1
        error('MaIA_SDCI:Logging:BlockNotFound', ...
            'Block "%s" was not found in the top-level model.', ...
            blockPath);
    end

    portHandles = get_param(blockPath, 'PortHandles');

    if isempty(portHandles.Outport) || portHandles.Outport(1) == -1
        error('MaIA_SDCI:Logging:MissingOutport', ...
            'Output port 1 of "%s" was not found.', ...
            blockPath);
    end

    portHandle = portHandles.Outport(1);
    lineHandle = get_param(portHandle, 'Line');

    if isempty(lineHandle) || lineHandle == -1
        error('MaIA_SDCI:Logging:SignalNotConnected', ...
            'Output port 1 of "%s" is not connected.', ...
            blockPath);
    end

    % Assign a stable name and enable logging.
    set_param(lineHandle, 'Name', signalName);
    set_param(portHandle, 'DataLogging', 'on');
    Simulink.sdi.markSignalForStreaming(portHandle, 'on');

end


%% DISPLAY

fprintf('GUI signal logging configured.\n');

for k = 1:numel(requiredSignals)
    fprintf('  %s\n', requiredSignals{k});
end

end