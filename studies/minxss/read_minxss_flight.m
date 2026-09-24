function [data, arcs, audit] = read_minxss_flight(path, p)
%READ_MINXSS_FLIGHT Preserve source order and split at every rejected row.
data.timeS = readColumn(path, 'HK.TIME');
data.jd = readColumn(path, 'HK.TIME_JD');
n = numel(data.timeS);
data.sourceRow = (1:n)';
data.eclipse = readColumn(path, 'HK.ECLIPSE_STATE');
data.sunBody = [readColumn(path,'HK.XACT_MEASSUNBODYVECTORX'), ...
    readColumn(path,'HK.XACT_MEASSUNBODYVECTORY'), ...
    readColumn(path,'HK.XACT_MEASSUNBODYVECTORZ')];
data.electricalW = zeros(n,3);
electricalComponentsGood = true(n,1);
for j = 1:3
    current = readColumn(path,sprintf('HK.EPS_SA%d_CUR',j));
    voltage = readColumn(path,sprintf('HK.EPS_SA%d_VOLT',j));
    data.electricalW(:,j) = current .* voltage / 1000;
    electricalComponentsGood = electricalComponentsGood & isfinite(current) & isfinite(voltage) ...
        & current>=0 & current<=600 & voltage>=0 & voltage<=25;
end
% Only these two deployed-panel channels are targets; no board temperatures drive them.
data.temperatureK = [readColumn(path,'HK.EPS_SA1_TEMP'), ...
    readColumn(path,'HK.EPS_SA3_TEMP')] + 273.15;
flags = [readColumn(path,'HK.CHECKBYTES_VALID'), ...
    readColumn(path,'HK.ADCS_TIME_VALID'), readColumn(path,'HK.ADCS_ATTITUDE_VALID'), ...
    readColumn(path,'HK.ADCS_REFS_VALID')];
mode = readColumn(path,'HK.SPACECRAFT_MODE');
reason = repmat("accepted",n,1);
reason(~all(flags==1,2)) = "invalid_packet_time_attitude_or_reference";
reason(reason=="accepted" & mode~=4) = "not_science_mode";
timeBad = ~isfinite(data.timeS) | ~isfinite(data.jd) | [false; diff(data.timeS)<=0];
reason(reason=="accepted" & timeBad) = "invalid_or_nonincreasing_time";
reason(reason=="accepted" & ~ismember(data.eclipse,[0 1])) = "invalid_eclipse_flag";
sunNorm = vecnorm(data.sunBody,2,2);
data.incidenceCosine = data.sunBody(:,1)./sunNorm;
sunGood = isfinite(sunNorm) & abs(sunNorm-1)<=0.05 ...
    & data.incidenceCosine>=cosd(p.maximumSunPointErrorDeg);
reason(reason=="accepted" & data.eclipse==0 & ~sunGood) = "invalid_sun_direction";
data.incidenceCosine(data.eclipse==1) = 0;
powerGood = electricalComponentsGood & all(isfinite(data.electricalW) & data.electricalW>=0 ...
    & data.electricalW<=15,2);
reason(reason=="accepted" & ~powerGood) = "invalid_electrical_power";
inconsistent = data.eclipse==1 & sum(data.electricalW,2)>p.maximumEclipseElectricalW;
reason(reason=="accepted" & inconsistent) = "eclipse_power_inconsistent";
tempGood = all(isfinite(data.temperatureK) & data.temperatureK>=p.temperatureRangeK(1) ...
    & data.temperatureK<=p.temperatureRangeK(2),2);
reason(reason=="accepted" & ~tempGood) = "invalid_target_temperature";
[arcs, segmentId] = minxss_segments(data.timeS, data.jd, reason=="accepted", p);
audit = table(data.sourceRow,reason,segmentId, ...
    'VariableNames',{'source_row','row_status','candidate_segment'});
data.accepted = reason=="accepted";
end

function value = readColumn(path,name)
value = double(ncread(path,name));
value = value(:);
end
