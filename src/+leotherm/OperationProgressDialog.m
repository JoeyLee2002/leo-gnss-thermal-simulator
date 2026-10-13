classdef OperationProgressDialog < handle
    %OPERATIONPROGRESSDIALOG Public UI controls with app-owned language states.
    properties (Dependent)
        Title
        Message
        Value
        Indeterminate
        Cancelable
        CancelText
        CancelRequested
    end
    properties (Access=private)
        Parent
        Panel
        Heading
        Body
        Track
        Fill
        StopButton
        Clock
        CancelFcn = []
        Listeners = {}
        Language
        TitleValue = ''
        MessageValue = ''
        ProgressValue = 0
        IndeterminateValue = 'off'
        CancelableValue = 'off'
        CancelTextValue = ''
        CancelRequestedValue = false
        Phase = 0
        ParentSize = []
        Deleting = false
    end
    methods
        function obj=OperationProgressDialog(parent,language,varargin)
            obj.Language=leotherm.normalizeLanguage(language);
            obj.Parent=parent;
            parser=inputParser;
            addParameter(parser,'Title',''); addParameter(parser,'Message','');
            addParameter(parser,'Value',0); addParameter(parser,'Indeterminate','off');
            addParameter(parser,'Cancelable','off');
            addParameter(parser,'CancelText',obj.t('停止计算','Stop computation'));
            addParameter(parser,'CancelFcn',[],@(value)isempty(value) || isa(value,'function_handle'));
            parse(parser,varargin{:});
            obj.Panel=uipanel(parent,'BackgroundColor',[1 1 1], ...
                'BorderType','line','Tag','OperationProgressPanel');
            grid=uigridlayout(obj.Panel,[4 1]);
            grid.Padding=[22 20 22 20]; grid.RowSpacing=14;
            grid.RowHeight={28,'1x',12,36};
            obj.Heading=uilabel(grid,'FontSize',18,'FontWeight','bold', ...
                'Tag','OperationProgressTitle');
            obj.Body=uilabel(grid,'WordWrap','on','FontSize',13, ...
                'VerticalAlignment','top','Interpreter','none','Tag','OperationProgressMessage');
            obj.Track=uipanel(grid,'BorderType','none','BackgroundColor',[0.88 0.92 0.92]);
            obj.Fill=uipanel(obj.Track,'BorderType','none','BackgroundColor',[0.08 0.48 0.46]);
            obj.StopButton=uibutton(grid,'Text','', ...
                'ButtonPushedFcn',@(~,~)obj.requestCancel,'Tag','OperationStopButton');
            obj.Listeners={addlistener(parent,'ObjectBeingDestroyed',@(~,~)delete(obj))};
            obj.CancelFcn=parser.Results.CancelFcn;
            settings=rmfield(parser.Results,'CancelFcn'); fields=fieldnames(settings);
            for k=1:numel(fields), obj.(fields{k})=settings.(fields{k}); end
            obj.layout;
            obj.Clock=timer('ExecutionMode','fixedSpacing','Period',0.2, ...
                'BusyMode','drop','TimerFcn',@(~,~)obj.tick);
            start(obj.Clock);
        end

        function close(obj)
            delete(obj);
        end

        function delete(obj)
            if obj.Deleting, return; end
            obj.Deleting=true;
            if ~isempty(obj.Clock) && isvalid(obj.Clock), stop(obj.Clock); delete(obj.Clock); end
            for k=1:numel(obj.Listeners)
                if isvalid(obj.Listeners{k}), delete(obj.Listeners{k}); end
            end
            if ~isempty(obj.Panel) && isvalid(obj.Panel), delete(obj.Panel); end
        end

        function requestCancel(obj)
            if strcmp(obj.CancelableValue,'on')
                obj.CancelRequested=true;
                if ~isempty(obj.CancelFcn), obj.CancelFcn(); end
            end
        end

        function state=getDisplayState(obj)
            state=struct('title',obj.Heading.Text,'message',obj.Body.Text, ...
                'buttonText',obj.StopButton.Text,'buttonEnabled',char(obj.StopButton.Enable), ...
                'cancelRequested',obj.CancelRequestedValue,'language',obj.Language);
        end

        function value=get.Title(obj), value=obj.TitleValue; end
        function set.Title(obj,value)
            obj.TitleValue=char(string(value)); obj.Heading.Text=obj.TitleValue;
        end
        function value=get.Message(obj), value=obj.Body.Text; end
        function set.Message(obj,value)
            obj.MessageValue=char(string(value)); obj.updateText;
        end
        function value=get.Value(obj), value=obj.ProgressValue; end
        function set.Value(obj,value)
            validateattributes(value,{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
            obj.ProgressValue=value; obj.drawBar;
        end
        function value=get.Indeterminate(obj), value=obj.IndeterminateValue; end
        function set.Indeterminate(obj,value)
            obj.IndeterminateValue=obj.onOff(value); obj.drawBar;
        end
        function value=get.Cancelable(obj), value=obj.CancelableValue; end
        function set.Cancelable(obj,value)
            obj.CancelableValue=obj.onOff(value); obj.updateText;
        end
        function value=get.CancelText(obj), value=obj.CancelTextValue; end
        function set.CancelText(obj,value)
            obj.CancelTextValue=char(string(value)); obj.updateText;
        end
        function value=get.CancelRequested(obj), value=obj.CancelRequestedValue; end
        function set.CancelRequested(obj,value)
            validateattributes(value,{'logical'},{'scalar'});
            obj.CancelRequestedValue=value; obj.updateText;
        end
    end
    methods (Access=private)
        function updateText(obj)
            if isempty(obj.Body) || ~isvalid(obj.Body), return; end
            obj.Body.Text=obj.MessageValue;
            obj.StopButton.Text=obj.CancelTextValue;
            obj.StopButton.Visible=obj.CancelableValue;
            obj.StopButton.Enable='on';
            if obj.CancelRequestedValue
                obj.Body.Text=obj.t('正在停止并保存任务状态...','Stopping and recording task status...');
                obj.StopButton.Text=obj.t('正在停止...','Stopping...');
                obj.StopButton.Enable='off';
            end
        end

        function layout(obj)
            if obj.Deleting || ~isvalid(obj.Parent) || ~isvalid(obj.Panel), return; end
            size=obj.Parent.Position(3:4);
            if isequal(size,obj.ParentSize), return; end
            obj.ParentSize=size;
            width=min(640,max(280,size(1)-32)); height=min(310,max(240,size(2)-32));
            obj.Panel.Position=[max(1,(size(1)-width)/2) max(1,(size(2)-height)/2) width height];
            obj.drawBar;
        end

        function tick(obj)
            if obj.Deleting || ~isvalid(obj.Track), return; end
            obj.layout;
            if strcmp(obj.IndeterminateValue,'on')
                obj.Phase=mod(obj.Phase+0.07,1);
            end
            obj.drawBar;
        end

        function drawBar(obj)
            if isempty(obj.Track) || ~isvalid(obj.Track) || isempty(obj.Fill) || ~isvalid(obj.Fill), return; end
            width=max(1,obj.Track.Position(3)); height=max(1,obj.Track.Position(4));
            if strcmp(obj.IndeterminateValue,'on')
                obj.Fill.Visible='on';
                obj.Fill.Position=[1+obj.Phase*width*0.7 1 max(1,width*0.25) height];
            else
                obj.Fill.Visible='off';
                if obj.ProgressValue>0, obj.Fill.Visible='on'; end
                obj.Fill.Position=[1 1 max(1,width*obj.ProgressValue) height];
            end
        end

        function text=t(obj,chinese,english)
            text=english; if strcmp(obj.Language,'zh'), text=chinese; end
        end
    end
    methods (Static,Access=private)
        function value=onOff(value)
            value=char(string(value));
            if ~ismember(value,{'on','off'})
                error('leotherm:ProgressProperty','Use on or off.');
            end
        end
    end
end
