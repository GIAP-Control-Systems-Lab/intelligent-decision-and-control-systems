function TwoTank_LiveDataCallback(data,time,signalID)
% TwoTank_LiveDataCallback
% Receives asynchronous Simulink Data Access packets from S5_MPC_Lab and
% forwards them to the currently open run_TwoTank GUI instance.

try
    if ~isappdata(groot,'S5_MPC_LiveReceiver')
        return;
    end

    receiver = getappdata(groot,'S5_MPC_LiveReceiver');
    if isempty(receiver) || ~isa(receiver,'function_handle')
        return;
    end

    receiver(data,time,signalID);
catch ME
    warning('S5_MPC_Lab:LiveDataCallback', ...
        'Two-tank live-data callback failed: %s',ME.message);
end
end
