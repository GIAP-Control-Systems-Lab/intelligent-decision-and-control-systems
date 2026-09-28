function CFG = project_config

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the global project configuration used by the model and GUI.

%% PROJECT

CFG = struct;

CFG.projectName = 'MaIA_SDCI';
CFG.modelName = 'MaIA_SDCI_Temperature_Control';

%% SIMULATION

CFG.simulation = struct;

CFG.simulation.stopTime = 1800;      % 30 min
CFG.simulation.pacing = 100.0;       % Simulation s / wall-clock s
CFG.simulation.pacingEnabled = true;

%% TEMPERATURE REFERENCES

CFG.reference = struct;

CFG.reference.fourRooms = [22; 21; 20; 19];   % [degC]
CFG.reference.singleRoom = 22;                 % Room 5 / ESC [degC]

%% SIGNAL LOGGING

CFG.logging = struct;

CFG.logging.enabled = true;
CFG.logging.signals = {'T_ref'; 'T_meas'; 'Q_heat'};

%% DISPLAY

fprintf('Project configuration loaded.\n');
fprintf('  Stop time:   %.1f s\n', CFG.simulation.stopTime);
fprintf('  References:  [%.1f %.1f %.1f %.1f] degC\n', CFG.reference.fourRooms);
fprintf('  ESC ref.:    %.1f degC\n', CFG.reference.singleRoom);

end