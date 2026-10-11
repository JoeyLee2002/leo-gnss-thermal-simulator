function value = sweep36_readable_protocol(protocol)
%SWEEP36_READABLE_PROTOCOL Export the full inputs with an explicit UTC epoch.
value=protocol;
if isfield(value,'createdUTC'), value=rmfield(value,'createdUTC'); end
epoch=value.scenario.startEpoch;
epoch.Format='yyyy-MM-dd''T''HH:mm:ssXXX';
value.scenario.startEpoch=char(epoch);
value.schema='leotherm.sweep36.protocol.v1';
value.units=struct('temperature','K','time','s','altitudeGrid','km', ...
    'scenarioAltitude','m','angles','deg','power','W', ...
    'capacity','J/K','conductance','W/K','area','m^2');
value.refinementCaseIds=[2 20 36];
value.refinementSamplesPerOrbit=720;
end
