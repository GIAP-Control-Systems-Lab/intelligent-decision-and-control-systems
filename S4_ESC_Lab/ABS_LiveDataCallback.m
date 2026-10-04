function ABS_LiveDataCallback(data,time,signalID)

try
    if ~isappdata(groot,'S4_ABS_LiveApp')
        return;
    end

    app = getappdata(groot,'S4_ABS_LiveApp');

    if isempty(app) || ~isvalid(app)
        return;
    end

    app.receiveLivePacket(signalID,data,time);

catch ME
    warning('S4_ESC_Lab:LiveDataCallback', ...
        'ABS live-data callback failed: %s',ME.message);
end

end
