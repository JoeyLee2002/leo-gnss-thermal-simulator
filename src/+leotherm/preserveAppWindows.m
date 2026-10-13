function cleanup=preserveAppWindows
%PRESERVEAPPWINDOWS Protect workbench windows from classic export side effects.
owners=findall(groot,'Type','figure','Tag','LEOThermMainWindow');
states=cell(numel(owners),2);
for index=1:numel(owners)
    states(index,:)={char(owners(index).Visible),char(owners(index).WindowState)};
end
cleanup=onCleanup(@() restoreWindows(owners,states));
end

function restoreWindows(owners,states)
for index=1:numel(owners)
    owner=owners(index);
    if ~isgraphics(owner,'figure') || strcmp(states{index,1},'off'), continue; end
    if strcmp(char(owner.WindowState),states{index,2}), continue; end
    owner.WindowState=states{index,2};
    if ~strcmp(states{index,2},'minimized')
        figure(owner);
        owner.WindowState=states{index,2};
    end
end
end
