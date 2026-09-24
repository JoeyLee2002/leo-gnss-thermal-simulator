function audit = telemetryPreflight(data,options,workflow)
%TELEMETRYPREFLIGHT Check mappings and sampled drivers without integrating.
if nargin<3, workflow=options.mode; end
options=leotherm.telemetryOptions(options);
good=data.accepted;
codes=strings(0,1); complete=true;
if ~strcmp(workflow,'validation')
    if strcmp(options.mode,'heat')
        if ~all(data.hasExternal), complete=false; codes(end+1)="missing_external_power"; end
        good=good & all(isfinite(data.externalPowerW) & data.externalPowerW>=0,2);
    else
        if ~all(data.hasPosition) || ~all(data.hasVelocity) || ~all(data.hasSun) || any(data.hasExternal)
            complete=false; codes(end+1)="incomplete_or_mixed_orbit_mapping";
        end
        if ~strcmp(options.frame,'J2000_ECI'), complete=false; codes(end+1)="unconfirmed_frame"; end
        c=leotherm.constants; r=vecnorm(data.positionM,2,2); v=vecnorm(data.velocityMps,2,2);
        sun=vecnorm(data.sunPositionM,2,2);
        good=good & all(isfinite([data.positionM data.velocityMps data.sunPositionM]),2) ...
            & r>c.radiusEarth & r<c.radiusEarth+50000e3 & v>0 & v<20e3 ...
            & vecnorm(cross(data.positionM,data.velocityMps,2),2,2)>0 ...
            & sun>0.8*c.astronomicalUnit & sun<1.2*c.astronomicalUnit;
        if any(data.hasAttitude,'all')
            if ~all(data.hasAttitude,'all'), complete=false; codes(end+1)="incomplete_attitude"; end
            for row=find(good)'
                frame=squeeze(data.frameBodyAxesECI(row,:,:));
                good(row)=all(isfinite(frame),'all') && max(abs(frame*frame'-eye(3)),[],'all')<=1e-6 ...
                    && abs(det(frame)-1)<=1e-6;
            end
        end
    end
    power=data.internalPowerW(:,data.hasInternal);
    boundary=data.boundaryTemperatureK(:,data.hasBoundaryTemperature);
    conductance=data.boundaryConductanceWK(:,data.hasBoundaryConductance);
    good=good & all(isfinite(power) & power>=0,2) ...
        & all(isfinite(boundary) & boundary>0,2) & all(isfinite(conductance) & conductance>=0,2);
end
if ~complete, good(:)=false; end
rows=find(good); lengths=[]; starts=[];
if ~isempty(rows)
    breaks=[true;diff(rows)~=1 | seconds(diff(data.epoch(rows)))>options.maxGapS];
    group=cumsum(breaks);
    for k=1:max(group)
        selected=rows(group==k);
        if numel(selected)>=2
            lengths(end+1)=seconds(data.epoch(selected(end))-data.epoch(selected(1))); %#ok<AGROW>
            starts(end+1)=selected(1); %#ok<AGROW>
        end
    end
end
longest=0; if ~isempty(lengths), longest=max(lengths); end
if isempty(lengths), codes(end+1)="no_contiguous_drivers"; end
if longest<=options.excludeInitialS, codes(end+1)="exclusion_removes_segments"; end
if ~any(data.hasTemperature), codes(end+1)="no_measured_temperature"; end
initialOK=true;
if options.useInitialTemperature && ~strcmp(workflow,'validation')
    initial=data.temperatureK(starts,data.hasTemperature);
    initialOK=any(data.hasTemperature) && all(isfinite(initial) & initial>0,'all');
    if ~initialOK, codes(end+1)="missing_initial_temperature"; end
end
if sum(good)<numel(good), codes(end+1)="rejected_driving_rows"; end
if isempty(codes), codes="structural_checks_passed"; end
temperatures=data.temperatureK(:,data.hasTemperature);
audit=struct('totalRows',numel(good),'validDriverRows',sum(good),'segmentCount',numel(lengths), ...
    'longestSegmentS',longest,'measuredNodes',sum(data.hasTemperature), ...
    'invalidTemperatures',sum(~isfinite(temperatures) | temperatures<=0,'all'), ...
    'ready',complete && ~isempty(lengths) && initialOK,'codes',codes,'acceptedDriverMask',good, ...
    'scope','mapping_and_driver_screen_only_not_solver_or_physical_validation');
end
