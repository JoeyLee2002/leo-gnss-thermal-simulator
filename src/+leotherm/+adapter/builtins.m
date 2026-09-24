function adapters = builtins
%BUILTINS Return adapters shipped with the workbench.
generic = struct;
generic.id = 'generic_exchange';
generic.version = '1.0.0';
generic.displayName = 'Generic MAT/JSON exchange';
generic.kind = 'file_exchange';
generic.capabilities = struct('readModel', true, 'writeModel', true, ...
    'readResult', true, 'writeResult', false, 'runExternal', false);
generic.handlers = struct('readModel', @leotherm.io.importThermalModel, ...
    'writeModel', @leotherm.io.exportThermalModel, ...
    'readResult', @leotherm.io.importThermalResult);
generic.exchangeFormats = {'MAT','JSON'};
generic.provenance = struct('source', 'leotherm', 'description', ...
    'Canonical thermal-model and thermal-result exchange adapter.');
adapters = leotherm.adapter.validate(generic);
end
