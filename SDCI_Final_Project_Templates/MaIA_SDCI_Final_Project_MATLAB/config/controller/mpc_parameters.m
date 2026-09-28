function [MPC, MPC_PLANT, MaIA_SDCI_MPC] = ...
        mpc_parameters(shared, MODEL)
% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Defines the parameters, plant model, and controller used by the MPC.

%% GENERAL PARAMETERS
MPC = struct;

MPC.numberOfRooms = shared.numberOfRooms;
MPC.numberOfManipulatedVariables = 4;
MPC.numberOfMeasuredDisturbances = 1;
MPC.numberOfMeasuredOutputs = 4;

MPC.dMin = shared.dMin;
MPC.dMax = shared.dMax;

MPC.sampleTime = [];
MPC.predictionHorizon = [];
MPC.controlHorizon = [];

%% INTERNAL PLANT MODEL
MPC.effectiveHeaterPower = ...
    MODEL.BLOCK_BASED.ACTUATOR.P_rated * MODEL.BLOCK_BASED.ACTUATOR.efficiency;

MPC_A = MODEL.BLOCK_BASED.PLANT.fourRooms.A;
MPC_B = MODEL.BLOCK_BASED.PLANT.fourRooms.B;
MPC_B(:,1:4) = MPC_B(:,1:4) * MPC.effectiveHeaterPower;
MPC_C = MODEL.BLOCK_BASED.PLANT.fourRooms.C;
MPC_D = MODEL.BLOCK_BASED.PLANT.fourRooms.D;

MPC_PLANT = ss(MPC_A, MPC_B, MPC_C, MPC_D);

MPC_PLANT.StateName = {'T1'; 'T2'; 'T3'; 'T4'};
MPC_PLANT.InputName = {'d1'; 'd2'; 'd3'; 'd4'; 'T_a'};
MPC_PLANT.OutputName = {'T1'; 'T2'; 'T3'; 'T4'};
MPC_PLANT.TimeUnit = 'seconds';

MPC_PLANT = setmpcsignals(MPC_PLANT, ...
    'MV', 1:4, ...
    'MD', 5, ...
    'MO', 1:4);

MPC.plantModel = MPC_PLANT;

%% MPC CONTROLLER
MPC.controllerFile = [];
MaIA_SDCI_MPC = [];
MPC.controller = [];

end