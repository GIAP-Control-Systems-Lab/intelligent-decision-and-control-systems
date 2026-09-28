function REPLICATOR = replicator_parameters(shared)
% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the parameters for the Replicator Dynamics controller.

%% GENERAL PARAMETERS
REPLICATOR = struct;

REPLICATOR.sampleTime = shared.sampleTime;
REPLICATOR.numberOfRooms = shared.numberOfRooms;

REPLICATOR.dMin = shared.dMin;
REPLICATOR.dMax = shared.dMax;

%% RESOURCE DEFINITION
REPLICATOR.maxRoomPower = shared.maxRoomPower;

REPLICATOR.maximumSystemPower = ...
    REPLICATOR.numberOfRooms * REPLICATOR.maxRoomPower;

REPLICATOR.totalPower = [];
REPLICATOR.initialAllocation = [];
REPLICATOR.maxAllocationPerRoom = [];

%% REPLICATOR DYNAMICS
REPLICATOR.payoffExponent = [];
REPLICATOR.gamma = [];
REPLICATOR.allocationTolerance = [];

end