function summary = run_paper_sweep36_v129(outputDirectory, maxCases, progress)
%RUN_PAPER_SWEEP36_V129 Controlled orbital and mounting-conductance study.
if nargin < 1, outputDirectory = []; end
if nargin < 2, maxCases = 36; end
if nargin < 3, progress=[]; end
validateattributes(maxCases, {'numeric'}, {'scalar','integer','>=',1,'<=',36});
[~, ~, out] = sweep36_paths(outputDirectory);
protocol = sweep36_protocol;
sourceFingerprint = sweep36_source_fingerprint;

if ~isfolder(out), mkdir(out); end
if ~isfile(fullfile(out,'protocol.mat'))
    save(fullfile(out,'protocol.mat'),'protocol','sourceFingerprint');
    sweep36_write_json(fullfile(out,'protocol.json'),sweep36_readable_protocol(protocol));
else
    saved = load(fullfile(out,'protocol.mat'),'protocol','sourceFingerprint');
    assert(isequaln(saved.protocol,protocol),'sweep36:ProtocolMismatch', ...
        'Saved protocol differs. Choose a new output directory.');
    assert(strcmp(saved.sourceFingerprint,sourceFingerprint),'sweep36:SourceMismatch', ...
        'Solver source changed. Choose a new output directory.');
end
rows = cell(36,1); count = 0;
for h = protocol.altitudeKm
    for b = protocol.betaDeg
        for g = protocol.conductanceWK
            count = count + 1;
            if count > maxCases, break; end
            leotherm.notifyProgress(progress,'case_start',count-1,36, ...
                sprintf('工况 %d / 36：%d km，beta %d 度，等效热导 %.2f W/K。',count,h,b,g), ...
                sprintf('Case %d / 36: %d km, beta %d deg, conductance %.2f W/K.',count,h,b,g));
            name = sprintf('case_%02d_h%d_b%02d_g%.2f',count,h,b,g);
            file = fullfile(out,[name '.mat']);
            timer = tic;
            if isfile(file)
                existing = load(file,'result','row','protocolId','sourceFingerprint');
                assert(strcmp(existing.protocolId,protocol.id) && ...
                    strcmp(existing.sourceFingerprint,sourceFingerprint),'sweep36:CacheMismatch', ...
                    'Cached case is from a different protocol or source.');
                [scenario,network] = sweep36_case(protocol,h,b,g,protocol.samplesPerOrbit);
                sweep36_validate_case(existing.result,scenario,network);
                recomputed = makeRow(existing.result,count,h,b,g,existing.row.elapsed_wall_s);
                assert(isequaln(recomputed,existing.row),'sweep36:CacheMismatch', ...
                    'Cached summary differs from saved results.');
                rows{count} = recomputed;
            else
                [scenario,network] = sweep36_case(protocol,h,b,g,protocol.samplesPerOrbit);
                result = leotherm.simulateScenario(scenario,network,progress);
                sweep36_validate_case(result,scenario,network);
                row = makeRow(result,count,h,b,g,toc(timer));
                assert(result.convergence.converged && all(isfinite(result.temperatureK(:))));
                assert(abs(row.actual_beta_deg-b)<0.02,'Unexpected beta geometry');
                protocolId = protocol.id;
                save(file,'result','row','protocolId','sourceFingerprint','-v7.3');
                rows{count} = row;
            end
            summary = struct2table(vertcat(rows{1:count}));
            writetable(summary,fullfile(out,'sweep36_summary.csv'));
            leotherm.notifyProgress(progress,'case_complete',count,36, ...
                sprintf('已保存 %d / 36 个工况。',count),sprintf('Saved %d / 36 cases.',count));
            fprintf('CASE %02d/36 h=%d beta=%d G=%.2f span=%.6f K lag=%.2f s cycles=%d elapsed=%.1f s\n', ...
                count,h,b,g,rows{count}.rf_span_k,rows{count}.harmonic_delay_s, ...
                rows{count}.warmup_cycles,toc(timer));
        end
        if count >= maxCases, break; end
    end
    if count >= maxCases, break; end
end
if maxCases < 36, return; end
assert(height(summary)==36);
% Repeat three prespecified conditions on a twice-finer time grid.
selected = [2 20 36]; refinement = cell(numel(selected),1);
for k = 1:numel(selected)
    i = selected(k); r = rows{i};
    leotherm.notifyProgress(progress,'refinement_start',k-1,3, ...
        sprintf('步长加密 %d / 3：工况 %d。',k,i),sprintf('Time refinement %d / 3: case %d.',k,i));
    name = sprintf('case_%02d_h%d_b%02d_g%.2f',i,r.altitude_km,r.target_beta_deg,r.conductance_wk);
    coarse = load(fullfile(out,[name '.mat']),'result');
    file = fullfile(out,[name '_refined.mat']);
    if isfile(file)
        saved = load(file,'result','sourceFingerprint');
        assert(strcmp(saved.sourceFingerprint,sourceFingerprint),'sweep36:CacheMismatch', ...
            'Refinement cache is from a different source.');
        result = saved.result;
    else
        [scenario,network] = sweep36_case(protocol,r.altitude_km,r.target_beta_deg,r.conductance_wk,720);
        result = leotherm.simulateScenario(scenario,network,progress);
        save(file,'result','sourceFingerprint','-v7.3');
    end
    [scenario,network] = sweep36_case(protocol,r.altitude_km,r.target_beta_deg,r.conductance_wk,720);
    sweep36_validate_case(result,scenario,network);
    fineTimes = result.timeS(1:2:end);
    assert(numel(fineTimes)==numel(coarse.result.timeS));
    assert(max(abs(fineTimes-coarse.result.timeS))<1e-7,'Time grids do not align');
    q.case_id = i;
    q.max_temperature_difference_k = max(abs(result.temperatureK(1:2:end,:)-coarse.result.temperatureK),[],'all');
    q.rf_span_difference_k = abs(result.metrics.rfTemperatureSpanK-r.rf_span_k);
    q.harmonic_delay_difference_s = abs(result.metrics.orbitalPhaseDelayS-r.harmonic_delay_s);
    q.coarse_step_s = r.time_step_s;
    q.refined_step_s = result.scenario.timeStepS;
    refinement{k} = q;
    leotherm.notifyProgress(progress,'refinement_complete',k,3, ...
        sprintf('已完成 %d / 3 个步长加密算例。',k),sprintf('Completed %d / 3 refinement cases.',k));
    fprintf('REFINEMENT case=%d maxT=%.6f K spanDiff=%.6f K delayDiff=%.4f s\n', ...
        i,q.max_temperature_difference_k,q.rf_span_difference_k,q.harmonic_delay_difference_s);
end
refinement = struct2table(vertcat(refinement{:}));
writetable(refinement,fullfile(out,'time_refinement.csv'));
save(fullfile(out,'sweep36_complete.mat'),'summary','protocol','refinement','sourceFingerprint');
sweep36_write_json(fullfile(out,'run_environment.json'),struct( ...
    'schema','leotherm.sweep36.run.v1','engineVersion',leotherm.version, ...
    'matlabVersion',version,'matlabRelease',version('-release'), ...
    'architecture',computer,'sourceFingerprint',sourceFingerprint, ...
    'completedUTC',char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ssXXX'))));
fprintf('PAPER_SWEEP36_COMPLETE\n');
end

function row = makeRow(r,id,h,b,g,elapsed)
row.case_id=id; row.altitude_km=h; row.target_beta_deg=b; row.conductance_wk=g;
row.actual_beta_deg=r.metrics.meanBetaDeg;
row.raan_deg=r.scenario.orbit.raanDeg;
row.period_s=r.orbit.periodS; row.duration_s=r.timeS(end); row.time_step_s=r.scenario.timeStepS;
row.eclipse_fraction=trapz(r.timeS,double(r.loads.visibleFraction<0.999))/r.timeS(end);
row.rf_min_k=min(r.temperatureK(:,9)); row.rf_max_k=max(r.temperatureK(:,9));
row.rf_mean_k=trapz(r.timeS,r.temperatureK(:,9))/r.timeS(end);
row.rf_span_k=r.metrics.rfTemperatureSpanK;
row.harmonic_delay_s=r.metrics.orbitalPhaseDelayS;
row.harmonic_available=r.metrics.orbitalPhaseAvailable;
row.harmonic_half_difference_s=r.metrics.orbitalPhaseHalfWindowDifferenceS;
row.peak_delay_s=r.metrics.forcingToRfLagS;
row.normalized_hysteresis=r.metrics.rfNormalizedHysteresisArea;
row.forcing_span_w=r.metrics.totalAbsorbedHeatSpanW;
row.warmup_cycles=r.convergence.cycles;
row.periodic_error_k=r.convergence.periodicErrorK;
row.end_to_start_max_k=max(abs(r.temperatureK(end,:)-r.temperatureK(1,:)));
row.mean_rf_to_structure_w=trapz(r.timeS,g*(r.temperatureK(:,9)-r.temperatureK(:,7)))/r.timeS(end);
row.elapsed_wall_s=elapsed;
end
