function ACTUATOR = simscape_actuator_parameters

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the parameters for the Physics-Based actuator model.


%% ELECTRICAL SUPPLY

ACTUATOR = struct;

ACTUATOR.V_rms = 240;   % [V RMS]
ACTUATOR.f_grid = 60;   % [Hz]


%% RESISTIVE HEATER

ACTUATOR.P_rated = 2500;   % [W]
ACTUATOR.R_heater = ACTUATOR.V_rms^2 / ACTUATOR.P_rated;   % [ohm]


%% MODULATION

ACTUATOR.controlWindow = 1;   % [s]
ACTUATOR.cyclesPerWindow = round(ACTUATOR.f_grid * ACTUATOR.controlWindow);


%% THERMAL CONVERSION

ACTUATOR.efficiency = 1.0;   % [-]

end