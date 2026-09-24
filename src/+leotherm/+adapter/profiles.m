function profiles = profiles
%PROFILES Describe common external thermal-software integration profiles.
% These are exchange/command profiles, not native parsers for proprietary
% formats. The user supplies an official exporter and executable path.
names = {'thermal_desktop','esatan_tms','sinda_fluint','openfoam'};
labels = {'Thermal Desktop','ESATAN-TMS','SINDA/FLUINT','OpenFOAM'};
notes = { ...
    'Use an official Thermal Desktop export or command-line batch interface.', ...
    'Use an ESATAN-TMS export or licensed batch interface.', ...
    'Use SINDA/FLUINT generated input decks and a controlled runner.', ...
    'Use OpenFOAM case directories and an explicit solver command.'};
profiles = repmat(struct('id','','displayName','','kind','external_command', ...
    'requiresOfficialExporter',true,'exchangeFormats',{{'MAT','JSON','CSV','Gmsh','STL/OBJ'}}, ...
    'note','','provenance',struct('source','leotherm','status','profile_only')), 1, numel(names));
for k = 1:numel(names)
    profiles(k).id = names{k};
    profiles(k).displayName = labels{k};
    profiles(k).note = notes{k};
end
end
