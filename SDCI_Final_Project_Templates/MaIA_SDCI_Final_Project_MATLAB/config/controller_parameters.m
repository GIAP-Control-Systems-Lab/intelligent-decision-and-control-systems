function [CTRL, CTRL_REPLICATOR, MPC_PLANT, MaIA_SDCI_MPC] = controller_parameters(MODEL)
% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Loads the shared and controller-specific configuration parameters.

%% CONFIGURATION FOLDERS
thisFile = mfilename('fullpath');
configFolder = fileparts(thisFile);
controllerFolder = fullfile(configFolder, 'controller');

if ~isfolder(controllerFolder)
    error('MaIA_SDCI:MissingControllerFolder', ...
        'Controller configuration folder was not found: %s', controllerFolder);
end

addpath(controllerFolder);

%% CONTROLLER STRUCTURE
CTRL = struct;

%% SHARED PARAMETERS
CTRL.shared = struct;
CTRL.shared.numberOfRooms = 4;
CTRL.shared.dMin = 0;
CTRL.shared.dMax = 1;
CTRL.shared.sampleTime = 1;   % [s]

%% ACTUATOR POWER
blockBasedPower = MODEL.BLOCK_BASED.ACTUATOR.P_rated;
physicsBasedPower = MODEL.SIMSCAPE.ACTUATOR.P_rated;

if ~isscalar(blockBasedPower) || ~isfinite(blockBasedPower) || blockBasedPower <= 0
    error('MaIA_SDCI:InvalidBlockBasedRatedPower', ...
        'Block-Based actuator rated power must be a positive finite scalar.');
end

if ~isscalar(physicsBasedPower) || ~isfinite(physicsBasedPower) || physicsBasedPower <= 0
    error('MaIA_SDCI:InvalidPhysicsBasedRatedPower', ...
        'Physics-Based actuator rated power must be a positive finite scalar.');
end

if abs(blockBasedPower - physicsBasedPower) > 1e-9
    error('MaIA_SDCI:InconsistentActuatorRatedPower', ...
        ['Block-Based and Physics-Based actuator rated powers must ', ...
         'be identical.']);
end

CTRL.shared.maxRoomPower = blockBasedPower;

%% CONTROLLERS
CTRL.ON_OFF = on_off_parameters(CTRL.shared);
CTRL.FUZZY = fuzzy_parameters(CTRL.shared);

[CTRL.MPC, MPC_PLANT, MaIA_SDCI_MPC] = ...
    mpc_parameters(CTRL.shared, MODEL);

CTRL.ESC = esc_parameters(CTRL.shared);
CTRL.REPLICATOR = replicator_parameters(CTRL.shared);

%% METADATA
CTRL.names = { ...
    'ON_OFF'; ...
    'FUZZY'; ...
    'MPC'; ...
    'ESC'; ...
    'REPLICATOR'};

CTRL.displayNames = { ...
    'ON/OFF'; ...
    'Fuzzy Logic'; ...
    'Model Predictive Control'; ...
    'Extremum Seeking Control'; ...
    'Replicator Dynamics'};

%% REPLICATOR STRUCTURE
CTRL_REPLICATOR = CTRL.REPLICATOR;

%% DISPLAY
fprintf('Controller parameters loaded.\n');
fprintf('  ON/OFF, Fuzzy, MPC, ESC, Replicator\n');

end