function checks = audit_sweep36_v129(dataDirectory, auditFile, progress)
%AUDIT_SWEEP36_V129 Independently check saved cases and their summary metrics.
[~,~,defaultOutput]=sweep36_paths;
if nargin<3, progress=[]; end
if nargin<1 || isempty(dataDirectory), dataDirectory=defaultOutput; end
folder=char(dataDirectory);
if nargin<2 || isempty(auditFile), auditFile=fullfile(defaultOutput,'audit.csv'); end
p=load(fullfile(folder,'protocol.mat'));
expectedProtocol=sweep36_protocol;
archivedProtocol=p.protocol;
if isfield(archivedProtocol,'createdUTC'), archivedProtocol=rmfield(archivedProtocol,'createdUTC'); end
assert(isequaln(archivedProtocol,expectedProtocol),'sweep36:ProtocolMismatch','Unexpected study protocol.');
t=readtable(fullfile(folder,'sweep36_summary.csv'));
assert(height(t)==36 && height(unique(t(:,{'altitude_km','target_beta_deg','conductance_wk'})))==36);
maximumClosure=0; maximumEndpoint=0;
forcing=[];
for i=1:36
    leotherm.notifyProgress(progress,'audit',i-1,36, ...
        sprintf('检查工况 %d / 36 的输入、温度和数值记录。',i), ...
        sprintf('Auditing case %d / 36: inputs, temperatures and numerical records.',i));
    file=sprintf('case_%02d_h%d_b%02d_g%.2f.mat',i,t.altitude_km(i),t.target_beta_deg(i),t.conductance_wk(i));
    s=load(fullfile(folder,file),'result'); r=s.result;
    [scenario,expectedNetwork]=sweep36_case(expectedProtocol,t.altitude_km(i),t.target_beta_deg(i),t.conductance_wk(i),360);
    sweep36_validate_case(r,scenario,expectedNetwork);
    assert(r.convergence.converged && r.convergence.periodicErrorK<=1e-3);
    assert(r.metrics.orbitalPhaseAvailable && all(isfinite(r.temperatureK(:))));
    assert(abs(r.timeS(end)/r.orbit.periodS-6)<1e-10);
    network=r.network;
    assert(network.conductanceWK(7,9)==t.conductance_wk(i));
    assert(network.conductanceWK(9,7)==t.conductance_wk(i));
    network.conductanceWK(7,9)=0.62; network.conductanceWK(9,7)=0.62;
    assert(isequaln(network,p.protocol.network),'Unintended hardware change');
    if mod(i-1,3)==0
        forcing=r.loads.totalExternalW;
    else
        assert(isequal(forcing,r.loads.totalExternalW),'External forcing changed with conductance');
    end
    assert(abs(r.metrics.rfTemperatureSpanK-t.rf_span_k(i))<1e-9);
    assert(abs(r.metrics.orbitalPhaseDelayS-t.harmonic_delay_s(i))<1e-8);
    maximumClosure=max(maximumClosure,max(abs(r.numerics.energyClosureResidualJ)));
    maximumEndpoint=max(maximumEndpoint,max(abs(r.temperatureK(end,:)-r.temperatureK(1,:))));
end
assert(maximumClosure<1e-3);
assert(maximumEndpoint<1e-3);
checks=table(36,true,true,true,true,maximumClosure,maximumEndpoint, ...
    'VariableNames',{'case_count','unique_factorial_design','periodic_initialization_passed', ...
    'only_target_link_changed','forcing_invariant_across_conductance','max_energy_closure_j','max_endpoint_difference_k'});
auditParent=fileparts(auditFile);
if ~isempty(auditParent)
    sweep36_safe_output(auditParent);
    if ~isfolder(auditParent), mkdir(auditParent); end
end
writetable(checks,auditFile);
disp(checks);
fprintf('SWEEP36_AUDIT_PASSED\n');
end
