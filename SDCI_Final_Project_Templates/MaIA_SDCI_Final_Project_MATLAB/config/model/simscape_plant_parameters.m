function PLANT = simscape_plant_parameters

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the parameters for the Physics-Based plant model.


%% THERMAL PARAMETERS

PLANT = struct;

PLANT.C = 7.476e4;      % [J/degC]
PLANT.alpha = 123.6;    % [W/degC]
PLANT.Ta = 8;           % [degC]


%% INITIAL CONDITIONS

PLANT.initialTemperature = PLANT.Ta * ones(4,1);
PLANT.initialTemperatureSingleRoom = PLANT.Ta;


%% BUILDING METADATA

PLANT.fourRooms = struct;
PLANT.fourRooms.numberOfRooms = 4;
PLANT.fourRooms.initialTemperature = PLANT.initialTemperature;

PLANT.singleRoom = struct;
PLANT.singleRoom.numberOfRooms = 1;
PLANT.singleRoom.initialTemperature = PLANT.initialTemperatureSingleRoom;

end