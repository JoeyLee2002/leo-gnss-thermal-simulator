function tests=test_report_figure_style
tests=functiontests(localfunctions);
end

function testDetailPreservesEveryTemperatureSeries(testCase)
[item,folder]=fixture('temperatures');
cleanup=onCleanup(@() rmdir(folder,'s'));
original=item.charts.y;
fig=leotherm.plotThermalReportDetail(item,fullfile(folder,'temperature.png'),'en');
cleanupFig=onCleanup(@() close(fig));
axesList=findall(fig,'Type','axes'); verifyEqual(testCase,numel(axesList),2);
curves=findall(fig,'Type','line'); verifyEqual(testCase,numel(curves),11);
for k=1:11
    found=false;
    for j=1:numel(curves), found=found || isequal(curves(j).YData(:),original(:,k)); end
    verifyTrue(testCase,found);
end
verifyEqual(testCase,axesList(1).YLim,axesList(2).YLim);
verifyTrue(testCase,isfile(fullfile(folder,'temperature.pdf')));
verifyEqual(testCase,item.charts.y,original);
end

function testZeroOpticsAndLabelsSurvive(testCase)
[item,folder]=fixture('optics');
cleanup=onCleanup(@() rmdir(folder,'s'));
fig=leotherm.plotThermalReportDetail(item,fullfile(folder,'optics.png'),'zh');
cleanupFig=onCleanup(@() close(fig));
b=findall(fig,'Type','bar'); verifyEqual(testCase,numel(b),3);
verifyTrue(testCase,any(arrayfun(@(x) all(x.YData([7 9 10 11])==0),b)));
axesList=findall(fig,'Type','axes');
verifyTrue(testCase,all(strcmp({axesList.FontName},'Microsoft YaHei')));
end

function testStyleIsLocal(testCase)
before=get(groot,'DefaultAxesFontName');
f=figure('Visible','off'); cleanup=onCleanup(@() close(f));
ax=axes(f); plot(ax,[0 1],[1 2]);
leotherm.styleThermalFigure(f,'en');
verifyEqual(testCase,get(groot,'DefaultAxesFontName'),before);
verifyEqual(testCase,ax.FontName,'Arial');
verifyEqual(testCase,char(ax.Box),'off');
end

function testConductanceMatrixRetainsLinksAndValues(testCase)
[item,folder]=fixture('conductance');
cleanup=onCleanup(@() rmdir(folder,'s'));
original=item.charts.y;
fig=leotherm.plotThermalReportDetail(item,fullfile(folder,'network.png'),'zh');
cleanupFig=onCleanup(@() close(fig));
ax=findall(fig,'Type','axes'); im=findall(ax,'Type','image');
verifyEqual(testCase,numel(im),1);
verifyEqual(testCase,im.CData,original);
verifyEqual(testCase,im.AlphaData,double(original>0));
verifyEqual(testCase,nnz(triu(original,1)),15);
verifyEqual(testCase,original,original');
verifyEqual(testCase,numel(ax.YTickLabel),11);
verifyTrue(testCase,contains(ax.YTickLabel{9},'射频前端'));
numbers=findall(ax,'Type','text'); count=0;
for k=1:numel(numbers)
    p=numbers(k).Position;
    if numel(p)<2 || p(1)<1 || p(1)>11 || p(2)<1 || p(2)>11, continue; end
    if p(1)~=round(p(1)) || p(2)~=round(p(2)), continue; end
    value=original(p(2),p(1));
    if value<=0, continue; end
    verifyEqual(testCase,numbers(k).String,sprintf('%.3g',value)); count=count+1;
end
verifyEqual(testCase,count,30);
verifyEqual(testCase,ax.UserData.conductanceMatrix,original);
verifyTrue(testCase,isfile(fullfile(folder,'network.pdf')));
end

function testCompactLabelsPreserveCustomNames(testCase)
labels={'9 GNSS RF front end','42 Custom sensor with unique name'};
actual=leotherm.thermalFigureLabels(labels);
verifyEqual(testCase,actual,{'9 RF front end','42 Custom sensor with unique name'});
end

function testSweepOmitsOnlyUnavailableMetricPanel(testCase)
folder=tempname; mkdir(folder); cleanup=onCleanup(@() rmdir(folder,'s'));
summary=table([500;500;600;600],[-20;20;-20;20], ...
    [0.3;0.2;0.3;0.2],[12;11;14;13],nan(4,1),[2;1;3;2], ...
    repmat({'complete'},4,1),'VariableNames',{'altitude_km','actual_beta_deg', ...
    'eclipse_fraction','response_temperature_span_k','orbital_phase_delay_s', ...
    'code_bias_span_m','status'});
fig=leotherm.plotSweep(summary,fullfile(folder,'sweep.png'),'en');
cleanupFig=onCleanup(@() close(fig));
verifyEqual(testCase,numel(findall(fig,'Type','axes')),3);
curves=findall(fig,'Type','line'); verifyEqual(testCase,numel(curves),6);
verifyEqual(testCase,sum(arrayfun(@(p) numel(p.YData),curves)),12);
verifyTrue(testCase,all(isnan(summary.orbital_phase_delay_s)));
end

function [item,folder]=fixture(stage)
s=leotherm.defaultScenario; s.durationS=120; s.timeStepS=60;
s.warmupOrbits=0; s.convergence.enabled=false;
r=leotherm.simulateScenario(s,leotherm.defaultReceiverNetwork);
items=leotherm.buildThermalReportDetails(struct('scenario',r));
item=items(strcmp({items.stage},stage));
folder=tempname; mkdir(folder);
end
