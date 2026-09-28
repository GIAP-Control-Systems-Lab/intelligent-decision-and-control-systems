function PLANT = block_based_plant_parameters

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the analytical thermal model for the Block-Based plant.


%% THERMAL PARAMETERS

PLANT = struct;

PLANT.C = 7.476e4;      % [J/degC]
PLANT.alpha = 123.6;    % [W/degC]
PLANT.Ta = 8;           % [degC]


%% INITIAL CONDITIONS

PLANT.initialTemperature = PLANT.Ta * ones(4,1);
PLANT.initialTemperatureSingleRoom = PLANT.Ta;


%% FOUR-ROOM MODEL

Cth = PLANT.C;
alpha = PLANT.alpha;

A4 = [
    -2*alpha/Cth,  alpha/Cth,          0,          0;
     alpha/Cth,   -3*alpha/Cth, alpha/Cth,          0;
              0,   alpha/Cth,  -3*alpha/Cth, alpha/Cth;
              0,            0,   alpha/Cth,  -2*alpha/Cth
];

% Inputs: [Q1; Q2; Q3; Q4; Ta]
B4 = [
    1/Cth,     0,     0,     0, alpha/Cth;
        0, 1/Cth,     0,     0, alpha/Cth;
        0,     0, 1/Cth,     0, alpha/Cth;
        0,     0,     0, 1/Cth, alpha/Cth
];

PLANT.fourRooms = struct;
PLANT.fourRooms.A = A4;
PLANT.fourRooms.B = B4;
PLANT.fourRooms.C = eye(4);
PLANT.fourRooms.D = zeros(4,5);
PLANT.fourRooms.initialTemperature = PLANT.initialTemperature;
PLANT.fourRooms.numberOfRooms = 4;


%% SINGLE-ROOM MODEL

PLANT.singleRoom = struct;
PLANT.singleRoom.A = -alpha/Cth;
PLANT.singleRoom.B = [1/Cth, alpha/Cth];
PLANT.singleRoom.C = 1;
PLANT.singleRoom.D = zeros(1,2);
PLANT.singleRoom.initialTemperature = PLANT.initialTemperatureSingleRoom;
PLANT.singleRoom.numberOfRooms = 1;

end