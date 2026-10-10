function handles=drawReportBodyLine(ax,value,y,justify)
%DRAWREPORTBODYLINE Justify non-final lines using actual rendered text extents.
value=char(value); left=0.075; right=0.925;
style={'FontName','Microsoft YaHei','FontSize',10,'Color',[0.17 0.22 0.23], ...
    'Interpreter','none','VerticalAlignment','middle','HorizontalAlignment','left'};
handles=text(ax,left,y,value,style{:});
if ~justify || isempty(value), return; end
% CJK characters may separate; Latin words and numerical tokens stay intact.
tokens={}; first=1;
while first<=numel(value)
    if isspace(value(first)), first=first+1; continue; end
    last=first;
    if value(first)<=255
        while last<numel(value) && value(last+1)<=255 && ~isspace(value(last+1))
            last=last+1;
        end
    end
    tokens{end+1}=value(first:last); %#ok<AGROW>
    first=last+1;
end
if numel(tokens)<2, return; end
delete(handles);
handles=gobjects(1,numel(tokens)); widths=zeros(1,numel(tokens));
for k=1:numel(tokens)
    handles(k)=text(ax,left,y,tokens{k},style{:});
    extent=get(handles(k),'Extent'); widths(k)=extent(3);
end
gap=(right-left-sum(widths))/(numel(tokens)-1);
if gap<0
    delete(handles);
    handles=text(ax,left,y,value,style{:});
    extent=get(handles,'Extent');
    set(handles,'FontSize',10*(right-left)/extent(3));
    return;
end
x=left;
for k=1:numel(handles)
    extent=get(handles(k),'Extent'); position=get(handles(k),'Position');
    position(1)=x-(extent(1)-position(1));
    set(handles(k),'Position',position);
    x=x+widths(k)+gap;
end
end
