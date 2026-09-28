function metricsTable = compute_metrics(tTemperature, T_ref, T_meas, ...
    tPower, Q_heat, controllerID)

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Computes performance metrics for one simulation run.


%% METRIC SETTINGS

settlingPercentage = 0.02;      % 2%
steadyStateFraction = 0.10;     % Final 10%


%% INPUT VALIDATION

tTemperature = tTemperature(:);
tPower = tPower(:);

if size(T_ref,1) ~= numel(tTemperature)
    error('MaIA_SDCI:MetricsReferenceLength', ...
        ['The number of rows in T_ref must match the number of ', ...
         'temperature time samples.']);
end

if size(T_meas,1) ~= numel(tTemperature)
    error('MaIA_SDCI:MetricsMeasurementLength', ...
        ['The number of rows in T_meas must match the number of ', ...
         'temperature time samples.']);
end

if size(Q_heat,1) ~= numel(tPower)
    error('MaIA_SDCI:MetricsPowerLength', ...
        'The number of rows in Q_heat must match the number of power time samples.');
end

if size(T_ref,2) < 4 || size(T_meas,2) < 4 || size(Q_heat,2) < 4
    error('MaIA_SDCI:MetricsSignalWidth', ...
        ['T_ref, T_meas and Q_heat must contain the common ', ...
         'four-channel project interface.']);
end

if numel(tTemperature) < 2 || numel(tPower) < 2
    error('MaIA_SDCI:MetricsInsufficientSamples', ...
        'At least two samples are required to compute metrics.');
end


%% ACTIVE ROOMS

% ESC uses channel 1 internally for the isolated fifth room.

if controllerID == 4
    activeChannels = 1;
    roomNames = {'Room_5'};
else
    activeChannels = 1:4;
    roomNames = {'Room_1', 'Room_2', 'Room_3', 'Room_4'};
end

numberOfRooms = numel(activeChannels);


%% METRIC ARRAYS

RMSE_degC = nan(numberOfRooms,1);
IAE_degC_s = nan(numberOfRooms,1);
ISE_degC2_s = nan(numberOfRooms,1);
SteadyStateError_degC = nan(numberOfRooms,1);
SettlingTime_s = nan(numberOfRooms,1);
Overshoot_degC = nan(numberOfRooms,1);
Energy_kWh = nan(numberOfRooms,1);
PeakPower_W = nan(numberOfRooms,1);


%% COMPUTE METRICS

for k = 1:numberOfRooms

    channel = activeChannels(k);

    %% Temperature data

    tref = T_ref(:,channel);
    tmeas = T_meas(:,channel);

    validTemperature = isfinite(tTemperature) & isfinite(tref) & isfinite(tmeas);

    tT = tTemperature(validTemperature);
    tref = tref(validTemperature);
    tmeas = tmeas(validTemperature);

    if numel(tT) < 2
        continue;
    end

    e = tref - tmeas;

    %% RMSE

    RMSE_degC(k) = sqrt(mean(e.^2));

    %% IAE

    IAE_degC_s(k) = trapz(tT, abs(e));

    %% ISE

    ISE_degC2_s(k) = trapz(tT, e.^2);

    %% Steady-state error

    nSteady = max(1, ceil(steadyStateFraction * numel(e)));
    steadyIndices = (numel(e) - nSteady + 1):numel(e);

    SteadyStateError_degC(k) = mean(e(steadyIndices));

    %% Settling time

    referenceFinal = tref(end);
    settlingTolerance = settlingPercentage * abs(referenceFinal);
    outsideBand = abs(e) > settlingTolerance;
    lastViolation = find(outsideBand, 1, 'last');

    if isempty(lastViolation)
        SettlingTime_s(k) = tT(1);
    elseif lastViolation < numel(tT)
        SettlingTime_s(k) = tT(lastViolation + 1);
    else
        SettlingTime_s(k) = NaN;
    end

    %% Overshoot

    positiveOvershoot = tmeas - tref;
    Overshoot_degC(k) = max(0, max(positiveOvershoot));

    %% Heater power

    q = Q_heat(:,channel);

    validPower = isfinite(tPower) & isfinite(q);

    tQ = tPower(validPower);
    q = q(validPower);

    if numel(tQ) >= 2
        Energy_kWh(k) = trapz(tQ, max(q,0)) / 3.6e6;
        PeakPower_W(k) = max(q);
    end

end


%% OUTPUT TABLE

Room = string(roomNames(:));

metricsTable = table(Room, RMSE_degC, IAE_degC_s, ISE_degC2_s, ...
    SteadyStateError_degC, SettlingTime_s, Overshoot_degC, ...
    Energy_kWh, PeakPower_W);

end