function tests=test_paper_study_report
tests=functiontests(localfunctions);
end
function testCompleteStudyKeepsAllFactors(testCase)
b=fixture; d=leotherm.buildPaperStudyReport(b);
verifyEqual(testCase,numel(d.charts),6);
verifyEqual(testCase,size(d.charts(1).y),[4 3]);
verifySubstring(testCase,strjoin(d.linesEn),'P95-P5');
verifySubstring(testCase,strjoin(d.linesEn),'all nodes');
end
function testDuplicateOrMissingFactorsFail(testCase)
b=fixture; b.metadata.paperStudy.summary(36)=b.metadata.paperStudy.summary(35);
verifyError(testCase,@() leotherm.buildPaperStudyReport(b),'leotherm:PaperStudyReport');
b=fixture; b.metadata.paperStudy.summary(36)=[];
verifyError(testCase,@() leotherm.buildPaperStudyReport(b),'leotherm:PaperStudyReport');
end
function testInvalidDelayAndConvergenceFail(testCase)
b=fixture; b.metadata.paperStudy.summary(1).harmonic_delay_s=NaN;
verifyError(testCase,@() leotherm.buildPaperStudyReport(b),'leotherm:PaperStudyReport');
b=fixture; b.metadata.paperStudy.summary(1).periodic_error_k=0.002;
verifyError(testCase,@() leotherm.buildPaperStudyReport(b),'leotherm:PaperStudyReport');
end
function testFreshDirectoryGuard(testCase)
folder=tempname; mkdir(folder); cleanup=onCleanup(@() rmdir(folder));
verifyError(testCase,@() leotherm.runPaperStudy(folder),'leotherm:PaperStudyOutput');
end
function b=fixture
root=fileparts(fileparts(mfilename('fullpath')));
t=readtable(fullfile(root,'studies','softwarex','sweep36','archive','sweep36','sweep36_summary.csv'));
b=struct('metadata',struct('paperStudy',struct('summary',table2struct(t))));
end
