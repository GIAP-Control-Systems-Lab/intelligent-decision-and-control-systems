function FUZZY = fuzzy_parameters(shared)
% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the parameters and FIS used by the Fuzzy Logic controller.

%% GENERAL PARAMETERS
FUZZY = struct;

FUZZY.sampleTime = shared.sampleTime;
FUZZY.numberOfRooms = shared.numberOfRooms;

FUZZY.dMin = shared.dMin;
FUZZY.dMax = shared.dMax;

FUZZY.initialDuty = [];

%% FUZZY RANGES
FUZZY.errorRange = [];
FUZZY.deltaErrorRange = [];
FUZZY.deltaDutyRange = [];

%% FIS
FUZZY.fisFile = [];
FUZZY.fis = [];

end