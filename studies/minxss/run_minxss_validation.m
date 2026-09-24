function runDir = run_minxss_validation(stage, runDir)
%RUN_MINXSS_VALIDATION Prepare, calibrate, then score frozen real-flight models.
% runDir = run_minxss_validation('prepare');
% run_minxss_validation('fit', runDir); run_minxss_validation('score', runDir);
root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'src'));
if nargin < 1, stage = 'all'; end
base = fullfile(root,'results','minxss_physical_validation');
if nargin < 2
    runDir = fullfile(base,['run_' char(datetime('now','Format','yyyyMMdd_HHmmss'))]);
end
switch stage
    case 'all'
        run_minxss_validation('prepare',runDir);
        run_minxss_validation('fit',runDir);
        run_minxss_validation('score',runDir);
    case 'prepare'
        assert(~isfolder(runDir),'Refusing to overwrite an existing experiment.');
        mkdir(runDir);
        p = minxss_protocol;
        writeJson(fullfile(runDir,'protocol_before_fit.json'),p);
        source = fullfile(base,'raw',p.sourceFile);
        assert(strcmp(minxss_hash_file(source),p.sourceSha256),'Unexpected source-file hash.');
        fprintf('Reading original Level 0C telemetry.\n');
        [data,arcs,audit] = read_minxss_flight(source,p);
        writetable(audit,fullfile(runDir,'row_audit.csv'));
        assert(~isempty(arcs),'No qualifying arcs. Do not relax quality gates silently.');
        manifest = arcManifest(arcs,data,p);
        writetable(manifest,fullfile(runDir,'arc_manifest_before_fit.csv'));
        disp(manifest);
        for label = {'train','validation','test'}
            count = sum(strcmp({arcs.split},label{1}));
            fprintf('%s arcs=%d\n',label{1},count);
            assert(count>=2,'Not enough %s arcs for this protocol.',label{1});
        end
        save(fullfile(runDir,'prepared.mat'),'data','arcs','p','source','-v7.3');
        fprintf('PREPARED_RUN=%s\n',runDir);
    case 'fit'
        assert(~isfile(fullfile(runDir,'frozen_models.mat')),'Models already frozen.');
        s = load(fullfile(runDir,'prepared.mat'));
        assert(isfield(s.p,'evidenceRole'), ...
            'Prepare a new development run with the current protocol; do not reuse an old blind-test label.');
        train = materialize(s.data,s.arcs(strcmp({s.arcs.split},'train')));
        validation = materialize(s.data,s.arcs(strcmp({s.arcs.split},'validation')));
        fprintf('Calibration uses %d train arcs; model selection uses %d validation arcs.\n', ...
            numel(train),numel(validation));
        fitOne = fitModel(train,'one_node',s.p.one,s.p,runDir);
        save(fullfile(runDir,'one_node_fit.mat'),'fitOne');
        fitTwo = fitModel(train,'two_node',s.p.two,s.p,runDir);
        save(fullfile(runDir,'two_node_fit.mat'),'fitTwo');
        leotherm.requireCalibrationConvergence(fitOne);
        leotherm.requireCalibrationConvergence(fitTwo);
        assert(max(fitOne.objective,fitTwo.objective)<1e11, ...
            'Calibration reached an invalid-state penalty, not an acceptable model.');
        vOne = objective(fitOne.parameters,validation,'one_node',s.p);
        vTwo = objective(fitTwo.parameters,validation,'two_node',s.p);
        selected = 'one_node';
        if sqrt(vTwo)<sqrt(vOne)-0.2, selected = 'two_node'; end
        frozen.one = fitOne; frozen.two = fitTwo;
        frozen.validationOneRMSEK = sqrt(vOne);
        frozen.validationTwoRMSEK = sqrt(vTwo);
        frozen.selected = selected;
        frozen.testReadForSelection = false;
        frozen.frozenAt = char(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd HH:mm:ss XXX'));
        frozen.protocol = s.p;
        frozen.softwareVersion = leotherm.version;
        save(fullfile(runDir,'frozen_models.mat'),'frozen');
        writeJson(fullfile(runDir,'frozen_models_before_test.json'),frozen);
        disp(frozen);
        fprintf('FROZEN: selected=%s validation one=%.4fK two=%.4fK\n', ...
            selected,sqrt(vOne),sqrt(vTwo));
    case 'score'
        assert(~isfile(fullfile(runDir,'results.mat')),'Test already scored; do not overwrite.');
        s = load(fullfile(runDir,'prepared.mat'));
        lock = load(fullfile(runDir,'frozen_models.mat'));
        frozen = lock.frozen;
        leotherm.requireCalibrationConvergence(frozen.one);
        leotherm.requireCalibrationConvergence(frozen.two);
        assert(isfield(s.p,'evidenceRole'),'Current reruns require an explicit development evidence role.');
        assert(isequaln(frozen.protocol,s.p),'Protocol changed after freezing.');
        sourceCheck.actualSHA256 = minxss_hash_file(s.source);
        assert(strcmp(sourceCheck.actualSHA256,s.p.sourceSha256),'Raw data changed before scoring.');
        sourceCheck.checkedBeforeTestScoring = true;
        writeJson(fullfile(runDir,'source_verification.json'),sourceCheck);
        records = materialize(s.data,s.arcs);
        [metrics,predictions,events,numerics] = scoreAll(records,frozen,s.p);
        writetable(metrics,fullfile(runDir,'all_arc_metrics.csv'));
        writetable(events,fullfile(runDir,'observed_segment_dynamics.csv'));
        writetable(numerics,fullfile(runDir,'timestep_convergence.csv'));
        for k = 1:numel(records)
            r = records(k);
            values = [r.input.elapsedS,r.temperatureK-273.15];
            names = {'elapsed_s','measured_minus_y_C','measured_plus_y_C'};
            for j = 1:numel(s.p.modelNames)
                name = s.p.modelNames{j};
                values = [values,predictions(k).(name)-273.15]; %#ok<AGROW>
                names = [names,{[name '_minus_y_C'],[name '_plus_y_C']}]; %#ok<AGROW>
            end
            T = array2table(values,'VariableNames',names);
            T.source_row = r.sourceRows;
            T.incidence_cosine = r.input.incidenceCosine;
            T.electrical_minus_y_W = r.input.electricalW(:,1);
            T.electrical_plus_y_W = r.input.electricalW(:,2);
            T.eclipse_flag = r.eclipse;
            writetable(T,fullfile(runDir,[r.id '_predictions.csv']));
        end
        summary = daySummary(metrics,frozen.selected);
        writetable(summary,fullfile(runDir,'heldout_day_summary.csv'));
        save(fullfile(runDir,'results.mat'),'metrics','predictions','records','events', ...
            'numerics','summary','frozen','-v7.3');
        minxss_write_report(runDir,metrics,summary,numerics,frozen,s.p);
        minxss_plot_results(runDir,metrics,predictions,records,frozen,s.p,'zh');
        minxss_plot_results(runDir,metrics,predictions,records,frozen,s.p,'en');
        audit_minxss_results(runDir);
        disp(summary);
        fprintf('SCORED_RUN=%s\n',runDir);
    otherwise
        error('minxss:Stage','Unknown stage.');
end
end

function manifest = arcManifest(arcs,data,p)
n = numel(arcs);
id = strings(n,1); split = id; day = id;
first = zeros(n,1); last = first; minutes = first; samples = first;
switches = first; shortSwitches = first;
for k = 1:n
    r = arcs(k).rows;
    id(k) = arcs(k).id; split(k) = arcs(k).split; day(k) = arcs(k).day;
    first(k)=r(1); last(k)=r(end); minutes(k)=arcs(k).durationS/60; samples(k)=numel(r);
    changes = find(diff(data.eclipse(r))~=0)+1;
    switches(k) = numel(changes);
    shortSwitches(k) = sum(diff(data.timeS(r(changes)))<120);
end
manifest = table(id,split,day,first,last,minutes,samples,switches,shortSwitches);
manifest.excluded_initial_minutes = repmat(p.excludeInitialS/60,n,1);
end

function records = materialize(data,arcs)
records = struct('input',{},'temperatureK',{},'sourceRows',{},'eclipse',{}, ...
    'id',{},'day',{},'split',{});
for k = 1:numel(arcs)
    rows = arcs(k).rows;
    r.input.elapsedS = data.timeS(rows)-data.timeS(rows(1));
    r.input.incidenceCosine = data.incidenceCosine(rows);
    r.input.electricalW = data.electricalW(rows,[1 3]);
    r.input.initialTemperatureK = data.temperatureK(rows(1),:);
    r.temperatureK = data.temperatureK(rows,:);
    r.sourceRows = rows;
    r.eclipse = data.eclipse(rows);
    r.id = arcs(k).id; r.day = arcs(k).day; r.split = arcs(k).split;
    records(end+1) = r; %#ok<AGROW>
end
end

function fit = fitModel(records,kind,bounds,p,runDir)
fprintf('FIT %s\n',kind);
fn = @(parameters) objective(parameters,records,kind,p);
fit = minxss_fit_bounded(fn,bounds,p.fit,fullfile(runDir,kind));
fprintf('%s training RMSE=%.4f parameters=',kind,sqrt(fit.objective));
fprintf(' %.6g',fit.parameters); fprintf('\n');
end

function value = objective(parameters,records,kind,p)
value = 0;
try
    for k = 1:numel(records)
        r = records(k);
        prediction = minxss_panel_predict(r.input,parameters,kind,p);
        w = weights(r.input.elapsedS,p.excludeInitialS);
        error = prediction-r.temperatureK;
        value = value + sum(w.*sum(error.^2,2))/(2*numel(records));
    end
catch exception
    if strcmp(exception.identifier,'leotherm:ThermalStateOutOfBounds')
        value = 1e12;
    else
        rethrow(exception);
    end
end
end

function w = weights(t,excludeS)
w = [diff(t);0]; w(t<excludeS)=0;
assert(sum(w)>0,'No scoring interval after initialization exclusion.');
w = w/sum(w);
end

function [metrics,predictions,events,numerics] = scoreAll(records,frozen,p)
rows = cell(0,15); erows = cell(0,12); nrows = cell(0,2);
emptyPrediction = cell2struct(cell(numel(p.modelNames),1),p.modelNames(:),1);
predictions = repmat(emptyPrediction,1,numel(records));
for k = 1:numel(records)
    r = records(k); t = r.input.elapsedS;
    w = weights(t,p.excludeInitialS);
    illumination = 'mixed';
    if all(r.eclipse==0), illumination='sunlight'; end
    if all(r.eclipse==1), illumination='eclipse'; end
    pred.literature_prior = minxss_panel_predict(r.input,p.one.initial,'one_node',p);
    pred.one_node = minxss_panel_predict(r.input,frozen.one.parameters,'one_node',p);
    pred.two_node = minxss_panel_predict(r.input,frozen.two.parameters,'two_node',p);
    pars = frozen.one.parameters;
    q = p.solarConstantWm2*p.areaM2*pars(2)*r.input.incidenceCosine ...
        -r.input.electricalW+pars(3:4);
    coefficient = p.areaM2*(p.frontEmissivity+p.backEmissivity)*5.670374419e-8;
    pred.no_storage = (max(0,q)/coefficient+p.deepSpaceK^4).^0.25;
    pred.persistence = repmat(r.input.initialTemperatureK,numel(t),1);
    predictions(k) = pred;
    for j = 1:numel(p.modelNames)
        name = p.modelNames{j};
        for panel = 1:2
            e = pred.(name)(:,panel)-r.temperatureK(:,panel);
            rmse = sqrt(sum(w.*e.^2)); bias = sum(w.*e);
            mae = sum(w.*abs(e)); tail = weightedQuantile(abs(e),w,0.95);
            measuredAmp = weightedQuantile(r.temperatureK(:,panel),w,0.95) ...
                -weightedQuantile(r.temperatureK(:,panel),w,0.05);
            predictedAmp = weightedQuantile(pred.(name)(:,panel),w,0.95) ...
                -weightedQuantile(pred.(name)(:,panel),w,0.05);
            passAbsolute = rmse<=p.acceptance.rmseK && abs(bias)<=p.acceptance.absoluteBiasK ...
                && tail<=p.acceptance.p95AbsoluteK;
            passAmplitude = abs(predictedAmp-measuredAmp)<=max( ...
                p.acceptance.amplitudeAbsoluteToleranceK,p.acceptance.amplitudeRelativeError*measuredAmp);
            rows(end+1,:) = {r.id,r.day,r.split,name,panel,sum(w>0),rmse,bias,mae,tail, ...
                measuredAmp,predictedAmp,passAbsolute,passAmplitude,illumination}; %#ok<AGROW>
        end
    end
    changes = find(diff(r.eclipse)~=0)+1;
    bounds = [1;changes;numel(t)+1];
    for j = 1:numel(bounds)-1
        a = max(bounds(j),find(t>=p.excludeInitialS,1)); b = bounds(j+1)-1;
        if a>=b || t(b)-t(a)<300, continue; end
        completePhase = j>1 && j<numel(bounds)-1 && t(bounds(j))>=p.excludeInitialS;
        for panel = 1:2
            actual = r.temperatureK(a:b,panel);
            model = pred.(frozen.selected)(a:b,panel);
            if r.eclipse(a)==1
                [~,i1]=min(actual); [~,i2]=min(model);
            else
                [~,i1]=max(actual); [~,i2]=max(model);
            end
            erows(end+1,:) = {r.id,r.day,r.split,panel,r.eclipse(a),t(a),t(b), ...
                actual(end)-actual(1),model(end)-model(1), ...
                t(a+i1-1)-t(a),t(a+i2-1)-t(a),completePhase}; %#ok<AGROW>
        end
    end
    if strcmp(r.split,'test')
        fine = p; fine.maximumStepS = 1;
        if strcmp(frozen.selected,'one_node')
            pars=frozen.one.parameters;
        else
            pars=frozen.two.parameters;
        end
        finePrediction = minxss_panel_predict(r.input,pars,frozen.selected,fine);
        difference = finePrediction-pred.(frozen.selected);
        nrows(end+1,:) = {r.id,max(abs(difference),[],'all')}; %#ok<AGROW>
    end
end
metrics = cell2table(rows,'VariableNames',{'arc','day','split','model','panel','score_samples', ...
    'rmse_K','bias_K','mae_K','p95_abs_K','observed_amplitude_K','predicted_amplitude_K', ...
    'pass_absolute','pass_amplitude','illumination'});
events = cell2table(erows,'VariableNames',{'arc','day','split','panel','eclipse','phase_start_s', ...
    'phase_end_s','observed_change_K','predicted_change_K','observed_extremum_delay_s', ...
    'predicted_extremum_delay_s','both_phase_boundaries_observed'});
numerics = cell2table(nrows,'VariableNames',{'arc','maximum_10s_vs_1s_difference_K'});
end

function v = weightedQuantile(x,w,probability)
valid = w>0;
[x,index] = sort(x(valid)); weightsOnly = w(valid); cumulative = cumsum(weightsOnly(index));
v = x(find(cumulative>=probability*cumulative(end),1));
end

function summary = daySummary(metrics,selected)
test = metrics(strcmp(metrics.split,'test'),:);
days = unique(test.day,'stable'); rows = {};
models = unique(test.model,'stable');
for d = 1:numel(days)
    for j = 1:numel(models)
        t = test(strcmp(test.day,days{d}) & strcmp(test.model,models{j}),:);
        rows(end+1,:) = {days{d},models{j},numel(unique(t.arc)),mean(t.rmse_K), ...
            mean(t.bias_K),all(t.pass_absolute),all(t.pass_amplitude), ...
            strcmp(models{j},selected)}; %#ok<AGROW>
    end
end
summary = cell2table(rows,'VariableNames',{'day','model','arcs','mean_rmse_K','mean_bias_K', ...
    'all_absolute_pass','all_amplitude_pass','selected_model'});
end

function writeJson(path,value)
fid=fopen(path,'w','n','UTF-8'); assert(fid>=0,'Cannot write %s.',path);
clean=onCleanup(@()fclose(fid));
fprintf(fid,'%s\n',jsonencode(value,'PrettyPrint',true));
end
