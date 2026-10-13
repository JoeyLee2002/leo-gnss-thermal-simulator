function uiAlert(parent,language,message,title,varargin)
%UIALERT Explicit acknowledgement text instead of locale-dependent defaults.
language=leotherm.normalizeLanguage(language);
label='OK'; if strcmp(language,'zh'), label='确定'; end
parser=inputParser; addParameter(parser,'Icon','error'); parse(parser,varargin{:});
uiconfirm(parent,message,title,'Options',{label},'DefaultOption',1, ...
    'CancelOption',1,'Icon',parser.Results.Icon);
end
