function tests=test_report_body_layout
tests=functiontests(localfunctions);
end

function testEnglishJustifiedEdges(testCase)
checkEdges(testCase,'External heat and conductive paths explain the response.');
end

function testChineseJustifiedEdges(testCase)
checkEdges(testCase,'外部吸热占比为 63.2%，响应节点的温度波动较小。');
end

function testLastLineNotExpanded(testCase)
[fig,ax]=pageAxes; cleanup=onCleanup(@() close(fig));
h=leotherm.drawReportBodyLine(ax,'Short last line.',0.5,false);
verifyEqual(testCase,numel(h),1);
verifyEqual(testCase,h.Position(1),0.075,'AbsTol',1e-12);
verifyLessThan(testCase,h.Extent(1)+h.Extent(3),0.925);
clear cleanup
end

function checkEdges(testCase,value)
[fig,ax]=pageAxes; cleanup=onCleanup(@() close(fig));
h=leotherm.drawReportBodyLine(ax,value,0.5,true);
verifyGreaterThan(testCase,numel(h),1);
first=h(1).Extent; last=h(end).Extent;
verifyEqual(testCase,first(1),0.075,'AbsTol',1e-6);
verifyEqual(testCase,last(1)+last(3),0.925,'AbsTol',1e-6);
for k=2:numel(h)
    before=h(k-1).Extent; current=h(k).Extent;
    verifyGreaterThanOrEqual(testCase,current(1)+1e-9,before(1)+before(3));
end
clear cleanup
end

function [fig,ax]=pageAxes
fig=figure('Visible','off','Position',[80 60 827 1169]);
ax=axes('Parent',fig,'Position',[0 0 1 1],'XLim',[0 1],'YLim',[0 1]);
end
