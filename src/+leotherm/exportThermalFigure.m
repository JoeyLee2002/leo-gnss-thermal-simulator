function exportThermalFigure(fig, path, language)
%EXPORTTHERMALFIGURE One source for report PNG and editable vector PDF.
leotherm.styleThermalFigure(fig,language);
s=leotherm.thermalFigureStyle(language);
[folder,stem,ext]=fileparts(path);
if ~isempty(folder) && ~isfolder(folder), mkdir(folder); end
drawnow;
if strcmpi(ext,'.pdf')
    exportgraphics(fig,path,'ContentType','vector','BackgroundColor','white');
else
    exportgraphics(fig,path,'Resolution',s.resolution,'BackgroundColor','white');
    exportgraphics(fig,fullfile(folder,[stem '.pdf']), ...
        'ContentType','vector','BackgroundColor','white');
end
end
