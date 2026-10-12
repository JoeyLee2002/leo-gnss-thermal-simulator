function capture_paper_tutorial(studyDirectory, outputDirectory)
%CAPTURE_PAPER_TUTORIAL Capture the production GUI and completed study assets.
root=fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'src'));
assert(~isfolder(outputDirectory),'Use a fresh capture directory.');
saved=load(fullfile(studyDirectory,'paper_study.mat'),'study');
assert(height(saved.study.summary)==36);
mkdir(outputDirectory);
for language={'zh','en'}
    lang=language{1}; folder=fullfile(outputDirectory,lang); mkdir(folder);
    app=leotherm.ThermalSimulatorApp('on',lang);
    cleanup=onCleanup(@() delete(app));
    app.Figure.Position=[40 40 1500 900];
    records=struct('image',{},'control',{},'rect',{});
    capture('01_start','');
    drop=findall(app.Figure,'Tag','QuickStartTemplate');
    drop.Value='paper'; callback=drop.ValueChangedFcn; callback(drop,[]);
    capture('02_paper','QuickStartTemplate');
    capture('03_run','QuickStartRunButton');
    r=saved.study.reference.scenario;
    app.runScenario(r.scenario,r.network);
    if strcmp(lang,'zh'), names={'仿真','单场景','热网络'};
    else, names={'Simulation','Single scenario','Thermal network'}; end
    tab=findall(app.Figure,'Type','uitab','Title',names{1});
    tab.Parent.SelectedTab=tab;
    tab=findall(app.Figure,'Type','uitab','Title',names{2});
    tab.Parent.SelectedTab=tab;
    capture('04_reference','');
    tab=findall(app.Figure,'Type','uitab','Title',names{3});
    tab.Parent.SelectedTab=tab;
    capture('05_network','');
    fid=fopen(fullfile(folder,'captures.json'),'w','n','UTF-8');
    fileCleanup=onCleanup(@() fclose(fid));
    fprintf(fid,'%s',jsonencode(records,'PrettyPrint',true)); clear fileCleanup
    clear cleanup
end
fid=fopen(fullfile(outputDirectory,'provenance.json'),'w','n','UTF-8');
cleanup=onCleanup(@() fclose(fid));
fprintf(fid,'%s',jsonencode(struct('softwareVersion',leotherm.version, ...
    'studyDirectory',studyDirectory,'method','Production MATLAB GUI state captures; control highlights are instructional overlays, not recorded mouse events.')));

    function capture(name,tag)
        drawnow; pause(1.2);
        file=[name '.png']; exportapp(app.Figure,fullfile(folder,file));
        rect=[];
        if ~isempty(tag)
            control=findall(app.Figure,'Tag',tag);
            p=getpixelposition(control,true);
            rect=[p(1),900-p(2)-p(4),p(3),p(4)];
        end
        records(end+1)=struct('image',file,'control',tag,'rect',rect);
    end
end
