function app = launch_app

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Opens or focuses the MaIA_SDCI control application.


%% APPLICATION IDENTIFICATION

appKey = 'Control_App_Instance';
runFlagName = 'MaIA_SDCI_RUN_FROM_GUI';


%% SIMULATION ORIGIN

runFromGUI = false;

if evalin('base', sprintf('exist(''%s'',''var'')', runFlagName))

    flagValue = evalin('base', runFlagName);

    if (islogical(flagValue) || isnumeric(flagValue)) && isscalar(flagValue)
        runFromGUI = logical(flagValue);
    end

end


%% EXISTING APPLICATION

app = [];

if isappdata(0, appKey)

    storedApp = getappdata(0, appKey);

    validApplication = isa(storedApp, 'Control_App') && isvalid(storedApp);

    if validApplication

        try
            validApplication = ~isempty(storedApp.UIFigure) && ...
                isvalid(storedApp.UIFigure);
        catch
            validApplication = false;
        end

    end

    if validApplication
        app = storedApp;
    else
        rmappdata(0, appKey);
    end

end


%% CREATE APPLICATION

if isempty(app)

    app = Control_App;
    setappdata(0, appKey, app);

end


%% BRING TO FRONT

app.bringToFront();
drawnow;


%% RESET GUI START FLAG

% Reset the flag after a simulation started from the GUI.

if runFromGUI
    assignin('base', runFlagName, false);
end

end