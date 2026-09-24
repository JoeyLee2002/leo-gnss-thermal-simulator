function adapter = register(adapter)
%REGISTER Register a user-supplied adapter descriptor.
adapter = leotherm.adapter.registry('register', adapter);
end
