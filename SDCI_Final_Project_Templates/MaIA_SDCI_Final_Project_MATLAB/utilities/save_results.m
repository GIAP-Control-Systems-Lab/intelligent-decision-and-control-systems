function savedFiles = save_results(metricsTable, appFigure, experimentName, resultsFolder)

% =========================================================================
% MaIA_SDCI Final Project
% Sistemas de Decision y Control Inteligente (SDCI)
% Universidad de los Andes, 2026
%
% Copyright (c) 2026 Leffer Trochez
% =========================================================================
%
% Saves the metrics table and application figure for one simulation run.


%% INPUT VALIDATION

if ~istable(metricsTable)
    error('MaIA_SDCI:InvalidMetricsTable', ...
        'metricsTable must be a MATLAB table.');
end

if nargin < 4 || isempty(resultsFolder)
    error('MaIA_SDCI:MissingResultsFolder', ...
        'A valid results folder must be provided.');
end

resultsFolder = char(string(resultsFolder));

if ~isfolder(resultsFolder)
    mkdir(resultsFolder);
end


%% EXPERIMENT NAME

if nargin < 3 || isempty(experimentName)
    experimentName = "Experiment";
end

experimentName = strtrim(string(experimentName));

if strlength(experimentName) == 0
    experimentName = "Experiment";
end

experimentName = regexprep(experimentName, '\s+', '_');
experimentName = regexprep(experimentName, '[<>:"/\\|?*]', '_');
experimentName = regexprep(experimentName, '_+', '_');
experimentName = regexprep(experimentName, '^_+|_+$', '');

if strlength(experimentName) == 0
    experimentName = "Experiment";
end


%% FILENAMES

timestamp = string(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
baseName = experimentName + "_" + timestamp;

csvFile = fullfile(resultsFolder, char(baseName + "_metrics.csv"));
pngFile = fullfile(resultsFolder, char(baseName + ".png"));


%% SAVE METRICS

writetable(metricsTable, csvFile);


%% SAVE APPLICATION FIGURE

if nargin < 2 || isempty(appFigure) || ~isvalid(appFigure)
    error('MaIA_SDCI:InvalidAppFigure', ...
        'A valid application figure handle is required to save the PNG.');
end

try
    exportapp(appFigure, pngFile);
catch
    try
        exportgraphics(appFigure, pngFile, 'Resolution', 200);
    catch ME
        error('MaIA_SDCI:PNGExportFailed', ...
            ['The metrics CSV was saved, but the PNG could not be ', ...
             'exported. Original error: %s'], ME.message);
    end
end


%% OUTPUT

savedFiles = struct;

savedFiles.baseName = char(baseName);
savedFiles.csv = csvFile;
savedFiles.png = pngFile;

fprintf('\nMaIA_SDCI results saved:\n');
fprintf('  CSV: %s\n', csvFile);
fprintf('  PNG: %s\n\n', pngFile);

end