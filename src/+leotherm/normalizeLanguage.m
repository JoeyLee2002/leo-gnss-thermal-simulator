function language = normalizeLanguage(language)
%NORMALIZELANGUAGE Return the canonical GUI and plotting language code.

if nargin < 1 || isempty(language)
    language = 'zh';
end
language = lower(strtrim(char(string(language))));
switch language
    case {'zh', 'cn', 'chinese', '中文'}
        language = 'zh';
    case {'en', 'english', '英文'}
        language = 'en';
    otherwise
        error('leotherm:InvalidLanguage', ...
            'Language must be zh/Chinese or en/English.');
end
end
