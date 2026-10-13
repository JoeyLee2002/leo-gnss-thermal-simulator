function answer=uiInputDialog(parent,language,prompts,title,dimensions,defaults)
%UIINPUTDIALOG Collect task inputs without locale-dependent default buttons.
language=leotherm.normalizeLanguage(language);
if ischar(prompts) || isstring(prompts), prompts=cellstr(prompts); end
count=numel(prompts);
assert(numel(defaults)==count,'leotherm:DialogInputs','Each input needs a default value.');
rows=ones(count,1);
if size(dimensions,1)==count, rows=max(1,dimensions(:,1)); end
height=80+sum(45+rows*22); width=560;
position=parent.Position;
fig=dialog('Name',title,'WindowStyle','modal','Resize','off', ...
    'Position',[position(1)+max(0,(position(3)-width)/2), ...
    position(2)+max(0,(position(4)-height)/2),width,height], ...
    'Visible','off','CloseRequestFcn',@(~,~)cancelInput(),'Tag','LocalizedInputDialog');
cleanup=onCleanup(@() deleteDialog(fig));
font='Arial'; if strcmp(language,'zh'), font='Microsoft YaHei'; end
fields=gobjects(count,1); top=height-15;
for k=1:count
    uicontrol(fig,'Style','text','String',prompts{k}, ...
        'FontName',font,'FontSize',11,'HorizontalAlignment','left', ...
        'Position',[20 top-28 width-40 28],'Tag',sprintf('InputPrompt_%d',k));
    fieldHeight=rows(k)*22;
    fields(k)=uicontrol(fig,'Style','edit','String',defaults{k},'Max',rows(k), ...
        'FontName',font,'FontSize',11,'HorizontalAlignment','left', ...
        'Position',[20 top-30-fieldHeight width-40 fieldHeight], ...
        'Tag',sprintf('InputValue_%d',k));
    top=top-45-fieldHeight;
end
ok='OK'; cancelText='Cancel';
if strcmp(language,'zh'), ok='确定'; cancelText='取消'; end
uicontrol(fig,'Style','pushbutton','String',ok,'FontName',font, ...
    'Position',[width-222 15 94 30],'Callback',@(~,~)acceptInput(),'Tag','InputAcceptButton');
uicontrol(fig,'Style','pushbutton','String',cancelText,'FontName',font, ...
    'Position',[width-116 15 94 30],'Callback',@(~,~)cancelInput(),'Tag','InputCancelButton');
answer={}; fig.UserData=false; fig.Visible='on';
waitfor(fig,'UserData',true);
clear cleanup

    function acceptInput
        if any(~isgraphics(fields)), return; end
        answer=arrayfun(@(field)field.String,fields,'UniformOutput',false);
        fig.UserData=true;
    end
    function cancelInput
        answer={}; fig.UserData=true;
    end
end

function deleteDialog(fig)
if isgraphics(fig), delete(fig); end
end
