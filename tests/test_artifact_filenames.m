function tests=test_artifact_filenames
tests=functiontests(localfunctions);
end
function testAsciiNamesStayCompatible(testCase)
verifyEqual(testCase,leotherm.englishArtifactFilename('thermal_report_zh.pdf','report.pdf'),'thermal_report_zh.pdf');
end
function testChineseNamesBecomeAscii(testCase)
name=leotherm.englishArtifactFilename('我的热仿真项目.mat','leotherm_project.mat');
verifyTrue(testCase,all(double(name)<=126));
verifyTrue(testCase,startsWith(name,'leotherm_project_'));
verifyTrue(testCase,endsWith(name,'.mat'));
verifyEqual(testCase,name,leotherm.englishArtifactFilename('我的热仿真项目.mat','leotherm_project.mat'));
end
function testDistinctNamesDoNotCollide(testCase)
a=leotherm.englishArtifactFilename('任务甲','task');
b=leotherm.englishArtifactFilename('任务乙','task');
verifyNotEqual(testCase,a,b);
end
function testPathInputIsRejected(testCase)
verifyError(testCase,@() leotherm.englishArtifactFilename('../report.pdf','report.pdf'),'leotherm:ArtifactFilename');
end
function testCompiledResourcesHaveAsciiNames(testCase)
root=fileparts(fileparts(mfilename('fullpath')));
folders={'src','templates','examples',fullfile('studies','softwarex','sweep36')};
for k=1:numel(folders)
    files=dir(fullfile(root,folders{k},'**','*'));
    for j=1:numel(files)
        verifyTrue(testCase,all(double(files(j).name)<=126),files(j).name);
    end
end
end
