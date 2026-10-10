function style = thermalFigureStyle(language)
%THERMALFIGURESTYLE Shared native MATLAB report/publication visual contract.
language = leotherm.normalizeLanguage(language);
style.font = 'Arial';
if strcmp(language,'zh'), style.font = 'Microsoft YaHei'; end
style.colors = [0.00 0.38 0.58; 0.82 0.37 0.12; 0.00 0.53 0.43; ...
    0.57 0.38 0.62; 0.76 0.60 0.13; 0.27 0.62 0.76];
style.nodeColors = [style.colors; 0.32 0.35 0.38; ...
    0.00 0.38 0.58; 0.82 0.37 0.12; 0.00 0.53 0.43; 0.57 0.38 0.62];
style.lineStyles = {'-','--',':','-.'};
style.fontSize = 10;
style.legendSize = 9;
style.widthCm = 18.3;
style.resolution = 300;
end
