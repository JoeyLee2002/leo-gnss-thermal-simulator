function adapter = generic_user_adapter
%GENERIC_USER_ADAPTER Minimal user extension example.
adapter = struct;
adapter.id = 'example_user_exchange';
adapter.version = '1.0.0';
adapter.displayName = 'Example user exchange adapter';
adapter.kind = 'file_exchange';
adapter.capabilities = struct('readModel', true, 'writeModel', true, ...
    'readResult', true, 'writeResult', false, 'runExternal', false);
adapter.handlers = struct('readModel', @leotherm.io.importThermalModel, ...
    'writeModel', @leotherm.io.exportThermalModel, ...
    'readResult', @leotherm.io.importThermalResult);
adapter.exchangeFormats = {'MAT','JSON'};
adapter.provenance = struct('source', 'examples/adapters/generic_user_adapter.m', ...
    'description', 'A safe starting point for a user-owned adapter.');
adapter = leotherm.adapter.validate(adapter);
end
