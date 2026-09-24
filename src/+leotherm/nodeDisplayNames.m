function labels = nodeDisplayNames(nodeNames, language)
%NODEDISPLAYNAMES Localize known thermal-node names for presentation.

language = leotherm.normalizeLanguage(language);
nodeNames = cellstr(string(nodeNames));
if strcmp(language, 'en')
    labels = cellfun(@englishLabel, nodeNames, 'UniformOutput', false);
else
    labels = cellfun(@chineseLabel, nodeNames, 'UniformOutput', false);
end
end

function value = chineseLabel(name)
switch name
    case 'face_+X_forward', value = '前向表面';
    case 'face_-X_aft', value = '后向表面';
    case 'face_+Y_orbit_left', value = '轨道左侧表面';
    case 'face_-Y_orbit_right', value = '轨道右侧表面';
    case 'face_+Z_nadir', value = '对地表面';
    case 'face_-Z_zenith', value = '天顶表面';
    case 'spacecraft_structure', value = '卫星主体结构';
    case 'gnss_antenna', value = '卫星导航天线';
    case 'gnss_rf_frontend', value = '卫星导航射频前端';
    case 'gnss_oscillator', value = '卫星导航振荡器';
    case 'receiver_digital', value = '接收机数字板';
    case 'zenith', value = '天顶表面';
    case 'nadir', value = '对地表面';
    case 'forward', value = '前向表面';
    case 'aft', value = '后向表面';
    case 'north', value = '北侧表面';
    case 'south', value = '南侧表面';
    case 'internal', value = '内部组件';
    otherwise, value = ['自定义节点：' name];
end
end

function value = englishLabel(name)
switch name
    case 'face_+X_forward', value = 'Forward face';
    case 'face_-X_aft', value = 'Aft face';
    case 'face_+Y_orbit_left', value = 'Orbit-left face';
    case 'face_-Y_orbit_right', value = 'Orbit-right face';
    case 'face_+Z_nadir', value = 'Nadir face';
    case 'face_-Z_zenith', value = 'Zenith face';
    case 'spacecraft_structure', value = 'Spacecraft structure';
    case 'gnss_antenna', value = 'GNSS antenna';
    case 'gnss_rf_frontend', value = 'GNSS RF front end';
    case 'gnss_oscillator', value = 'GNSS oscillator';
    case 'receiver_digital', value = 'Receiver digital board';
    case 'zenith', value = 'Zenith face';
    case 'nadir', value = 'Nadir face';
    case 'forward', value = 'Forward face';
    case 'aft', value = 'Aft face';
    case 'north', value = 'North face';
    case 'south', value = 'South face';
    case 'internal', value = 'Internal component';
    otherwise, value = ['Custom node: ' name];
end
end
