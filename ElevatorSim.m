function ElevatorSim()
    
    %%Palette
    c_bg = [234, 224, 207] / 255;     %Background
    c_prim = [84, 119, 146] / 255;    %primary 
    c_acc = [148, 180, 193] / 255;    %accent 
    c_text = [33, 52, 72] / 255;       %Texts

    floors = 0:4;
    elevatorSpeed = 0.05; %speed of movement per tick
    tickRate = 0.05;      % seconds
    state = struct();
    state.currentPos = 0;       %from 0:4
    state.currentFloor = 0;     %current floor
    state.direction = 0;        %0=Idle 1=Up -1=Down
    state.doorTimer = 0;        %>0 means doors are open/processing
    state.requests = [];        %array of requested floors
    state.logicMode = 'SCAN';   %FCFS or SCAN
    state.regime = 'NORMAL';    %NORMAL NIGHT RUSH
    state.emergency = 'NONE';   %NONE FIRE FLOOD STORM
    state.idleTimer = 0;        %counter for idle return logic
    %GUI
    f = figure('Name', 'Smart Elevator Simulation', 'NumberTitle', 'off','Position', [100, 100, 900, 600], 'Color', c_bg,'MenuBar', 'none', 'ToolBar', 'none', 'Resize', 'off');
  
    ax = axes('Parent', f, 'Position', [0.05, 0.1, 0.35, 0.8], 'Color', c_bg * 0.8, 'XColor', 'none', 'YColor', 'none', 'XLim', [0, 2], 'YLim', [-0.5, 4.5]);
    hold(ax, 'on');
    
    for i = floors
        plot(ax, [0, 2], [i, i], 'Color', c_text, 'LineWidth', 2);
        text(ax, 0.1, i + 0.2, sprintf('Floor %d', i), 'Color', c_text, 'FontSize', 10);
    end
   
    carWidth = 0.8;
    carHeight = 0.8;
   
    carRect = rectangle(ax, 'Position', [0.6, 0, carWidth, carHeight],'FaceColor', c_prim, 'EdgeColor', c_text, 'LineWidth', 2);
    
    
    doorLine = plot(ax, [1, 1], [0, 0.8], 'Color', c_bg, 'LineWidth', 3);
  
    statusText = uicontrol('Style', 'text', 'Parent', f, 'Units', 'normalized','Position', [0.05, 0.92, 0.35, 0.05],'String', 'Status: IDLE', 'BackgroundColor', c_bg,'ForegroundColor', c_acc, 'FontSize', 12, 'FontWeight', 'bold');
  
    panelX = 0.45;
    
    % Floor request buttons
    uicontrol('Style', 'text', 'Parent', f, 'Units', 'normalized','Position', [panelX, 0.85, 0.5, 0.05], 'String', 'Internal Panel / Floor Calls', ...
              'BackgroundColor', c_bg, 'ForegroundColor', c_text, 'FontSize', 11);
          
    btnHandles = zeros(1, 5);
    for i = 0:4
        btnHandles(i+1) = uicontrol('Style', 'pushbutton', 'Parent', f, ...
                  'Units', 'normalized', ...
                  'Position', [panelX + (i*0.1), 0.78, 0.08, 0.06], ...
                  'String', num2str(i), ...
                  'FontSize', 12, 'FontWeight', 'bold', ...
                  'BackgroundColor', c_prim, 'ForegroundColor', 'k', ...
                  'Callback', @(src, ~) requestFloor(i, src));
    end
    % Logicmode selection
    uicontrol('Style', 'text', 'Parent', f, 'Units', 'normalized', ...
              'Position', [panelX, 0.68, 0.2, 0.04], 'String', 'Logic Mode:', ...
              'BackgroundColor', c_bg, 'ForegroundColor', c_text, 'HorizontalAlignment', 'left');
    
    bgLogic = uibuttongroup('Parent', f, 'Units', 'normalized', ...
                            'Position', [panelX, 0.62, 0.25, 0.06], ...
                            'BackgroundColor', c_bg, 'BorderType','none', ...
                            'SelectionChangedFcn', @changeLogic);
                        
    uicontrol(bgLogic, 'Style', 'radiobutton', 'Units', 'normalized', ...
              'Position', [0.05, 0, 0.45, 1], 'String', 'SCAN', ...
              'Tag', 'SCAN', 'ForegroundColor', c_text, 'BackgroundColor', c_bg);
    uicontrol(bgLogic, 'Style', 'radiobutton', 'Units', 'normalized', ...
              'Position', [0.55, 0, 0.45, 1], 'String', 'FCFS', ...
              'Tag', 'FCFS', 'ForegroundColor', c_text, 'BackgroundColor', c_bg);
    % rregime selection
    uicontrol('Style', 'text', 'Parent', f, 'Units', 'normalized', ...
              'Position', [panelX + 0.28, 0.68, 0.2, 0.04], 'String', 'Time Regime:', ...
              'BackgroundColor', c_bg, 'ForegroundColor', c_text, 'HorizontalAlignment', 'left');
    
    bgRegime = uibuttongroup('Parent', f, 'Units', 'normalized', ...
                             'Position', [panelX + 0.28, 0.62, 0.25, 0.06], ...
                             'BackgroundColor', c_bg, 'BorderType', 'none', ...
                             'SelectionChangedFcn', @changeRegime);
                         
    uicontrol(bgRegime, 'Style', 'radiobutton', 'Units', 'normalized', ...
              'Position', [0, 0, 0.3, 1], 'String', 'Day', ...
              'Tag', 'NORMAL', 'ForegroundColor', c_text, 'BackgroundColor', c_bg);
    uicontrol(bgRegime, 'Style', 'radiobutton', 'Units', 'normalized', ...
              'Position', [0.33, 0, 0.3, 1], 'String', 'Night', ...
              'Tag', 'NIGHT', 'ForegroundColor', c_text, 'BackgroundColor', c_bg);
    uicontrol(bgRegime, 'Style', 'radiobutton', 'Units', 'normalized', ...
              'Position', [0.66, 0, 0.3, 1], 'String', 'Rush', ...
              'Tag', 'RUSH', 'ForegroundColor', c_text, 'BackgroundColor', c_bg);
    %emergency controls
        uicontrol('Style', 'text', 'Parent', f, 'Units', 'normalized', ...
                'Position', [panelX, 0.50, 0.5,0.04], 'String', 'EMERGENCY OVERRIDES', ...
                'BackgroundColor', c_bg, 'ForegroundColor', 'r', 'FontWeight', 'bold');
          
    uicontrol('Style', 'pushbutton', 'Parent', f, 'Units', 'normalized', ...
              'Position', [panelX, 0.42,0.15, 0.06], 'String', 'FIRE (G)', ...
              'BackgroundColor', [0.6, 0,0], 'ForegroundColor', 'w', ...
              'Callback', @(~,~) setEmergency('FIRE'));
          
    uicontrol('Style', 'pushbutton', 'Parent', f, 'Units', 'normalized', ...
              'Position', [panelX+0.17, 0.42,0.15, 0.06], 'String', 'STORM (Mid)', ...
              'BackgroundColor', [0.6,0.5, 0], 'ForegroundColor', 'w', ...
              'Callback', @(~,~) setEmergency('STORM'));
          
    uicontrol('Style', 'pushbutton', 'Parent', f, 'Units', 'normalized', ...
              'Position', [panelX+0.34,0.42, 0.15, 0.06], 'String', 'FLOOD (Top)', ...
              'BackgroundColor', [0, 0,0.6], 'ForegroundColor', 'w', ...
              'Callback', @(~,~) setEmergency('FLOOD'));
    
    
    
    
    uicontrol('Style', 'pushbutton', 'Parent', f, 'Units', 'normalized', ...
              'Position', [panelX,0.35, 0.49, 0.05], 'String', 'CLEAR EMERGENCY / RESET', ...
              'BackgroundColor', c_prim, 'ForegroundColor', 'k', ...
              'Callback', @(~,~) setEmergency('NONE'));
    % Logger
    uicontrol('Style', 'text', 'Parent', f, 'Units', 'normalized', ...
              'Position', [panelX, 0.28,0.5, 0.04], 'String', 'System Logs', ...
              'BackgroundColor', c_bg, 'ForegroundColor', c_text, 'HorizontalAlignment', 'left');
    logList = uicontrol('Style', 'listbox', 'Parent', f, 'Units', 'normalized', ...
                        'Position', [panelX, 0.05,0.49, 0.23], ...
                        'BackgroundColor', c_bg*0.8, 'ForegroundColor', c_text, 'FontSize', 9);
    
    logMsg('System initialized. Ready.');
    %main simulation 
    t = timer('ExecutionMode', 'fixedRate', 'Period',tickRate, ...
              'TimerFcn', @gameLoop);
    start(t);
    
    % cleanup on window close
    f.CloseRequestFcn = @cleanup;
    % ---------------------------------------------------------------------
    % --- -----------------------------------------------
    % ---------------------------------------------------------------------
 % ---------------------------------------------------------------------
    function cleanup(~, ~)
        stop(t);
        delete(t);
        delete(f);
    end
    function logMsg(msg)
        % adds a timestamped message to the log window
        currentLogs = get(logList, 'String');
        timeStr = datestr(now, 'HH:MM:SS');
        newLog = sprintf('[%s] %s', timeStr, msg);
        if ischar(currentLogs)
            set(logList, 'String', {newLog});
        else
            set(logList, 'String', [{newLog}; currentLogs(1:min(end, 15))]);
        end
    end
    function requestFloor(floorNum, btn)
        if ~strcmp(state.emergency, 'NONE')
            logMsg('ERR: Emergency Active. Calls rejected.');
            return;
        end
        % only add if not already in queue and not currently at that floor with doors open
        if ~ismember(floorNum, state.requests)
             if floorNum == state.currentFloor && state.doorTimer > 0
                 return; % already here and open
             end
            state.requests(end+1) = floorNum;
            set(btn, 'BackgroundColor', c_acc, 'ForegroundColor', 'k'); % highlight button
            logMsg(sprintf('Call received: Floor %d', floorNum));
        end
    end
    function changeLogic(~, event)
        state.logicMode = event.NewValue.Tag;
        logMsg(sprintf('Logic Mode: %s', state.logicMode));
    end
    function changeRegime(~, event)
        state.regime = event.NewValue.Tag;
        logMsg(sprintf('Regime Change: %s', state.regime));
    end
    function setEmergency(type)
        state.emergency = type;
        if strcmp(type, 'NONE')
            logMsg('Emergency Cleared. Resuming Normal Operation.');
            set(statusText, 'ForegroundColor', c_acc, 'String', 'Status: IDLE');
            set(btnHandles, 'BackgroundColor', c_prim, 'ForegroundColor', 'k');
        else
            state.requests = [];                    %clear all user requests
            % rreset all botton colors
            set(btnHandles, 'BackgroundColor', c_prim, 'ForegroundColor', 'k');
            logMsg(sprintf('!!! EMERGENCY: %s PROTOCOL INITIATED !!!', type));
            set(statusText, 'ForegroundColor', 'r', 'String', sprintf('Status: %s', type));
        end
    end
    

%CORE ENGINE
    % >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>><<<


    function gameLoop(~, ~)
                 %update Graphics
        yPos = state.currentPos;
        %move the rectangle
        set(carRect, 'Position', [0.6, yPos - (carHeight/2), carWidth, carHeight]);
        % ove the door line visual effect
        if state.doorTimer > 0
            %doors open line shrinks
            set(doorLine, 'YData', [yPos - (carHeight/2), yPos - (carHeight/2)]); 
        else
            %doors closed line full
            set(doorLine, 'YData', [yPos - (carHeight/2), yPos + (carHeight/2)]);
        end
        %%%2: Emergency Handling
        if ~strcmp(state.emergency, 'NONE')
            target = 0;
            if strcmp(state.emergency, 'FIRE'), target = 0; end   %ground
            if strcmp(state.emergency, 'STORM'), target = 2; end  % middle
            if strcmp(state.emergency, 'FLOOD'), target = 4; end  % top
            
            if abs(state.currentPos - target) < 0.05
                state.currentPos = target;
                state.doorTimer = 10; %keep doors open
                set(statusText, 'String', sprintf('EMERGENCY HOLD: FLR %d', target));
            else
                moveTowards(target);
            end
            return;
        end
        % 3. door/wait logic
        if state.doorTimer > 0
            state.doorTimer = state.doorTimer - 1;
            if state.doorTimer == 0
                logMsg('Doors Closing...');
            end
            return; %do not move while doors are processing
        end
        %%%%%%%%%%%%%%%arrival logic 
        if abs(state.currentPos - round(state.currentPos)) < 0.06
            flr = round(state.currentPos);
            
            shouldStop = false;
            if isempty(state.requests)
                shouldStop = false;
            elseif strcmp(state.logicMode, 'FCFS')
               
                if flr == state.requests(1)
                    shouldStop = true;
                end
            else
        
                if ismember(flr, state.requests)
                    shouldStop = true;
                end
            end
            if shouldStop
                
                state.currentPos = flr; 
                state.requests(state.requests == flr) = []; 
                state.doorTimer = 30; 
                state.currentFloor = flr;
                
                
                set(btnHandles(flr+1), 'BackgroundColor', c_prim, 'ForegroundColor', 'k');
                logMsg(sprintf('Arrived Floor %d. Doors Opening.', flr));
                return;
            end
        end
        % 5. movement Logic
        if isempty(state.requests)
            handleIdleBehavior();
        else
            state.idleTimer = 0; 
            if strcmp(state.logicMode, 'FCFS')
                target = state.requests(1);
                moveTowards(target);
            else
                moveSCAN();
            end
        end
    end
    function handleIdleBehavior()
        % smart Regime Logic  it rreturn to specific floors when idle
        state.idleTimer = state.idleTimer + 1;
        threshold = 50; 
        if strcmp(state.regime, 'RUSH'), threshold = 20; end 
        
        if state.idleTimer > threshold
            target = -1;
            if strcmp(state.regime, 'NIGHT'), target = 0; end 
            if strcmp(state.regime, 'RUSH'), target = 0; end  
            
            if target ~= -1 && abs(state.currentPos - target) > 0.1
                set(statusText, 'String', sprintf('Regime Return: %d', target));
                moveTowards(target);
            else
                set(statusText, 'String', 'Status: IDLE');
            end
        else
             set(statusText, 'String', 'Status: IDLE');
        end
    end
    function moveTowards(target)
        if state.currentPos < target
            state.currentPos = state.currentPos + elevatorSpeed;
            state.direction = 1;
            set(statusText, 'String', 'Status: GOING UP');
        elseif state.currentPos > target
            state.currentPos = state.currentPos - elevatorSpeed;
            state.direction = -1;
            set(statusText, 'String', 'Status: GOING DOWN');
        end
        
        state.currentPos = max(0, min(4, state.currentPos));
    end
    function moveSCAN()
        curr = state.currentPos;
        
        epsilon = 0.01; 
        
        
        if state.direction == 0
             
             if state.requests(1) > curr, state.direction = 1; else, state.direction = -1; end
        end
        
        
            reqsAbove = state.requests(state.requests > curr + epsilon);
            reqsBelow = state.requests(state.requests < curr - epsilon);
        
        
        shouldSwitch = false;
        
        if state.direction == 1 && isempty(reqsAbove)
            shouldSwitch = true;
        elseif state.direction == -1 && isempty(reqsBelow)
            shouldSwitch = true;
        end
        
        if shouldSwitch
            state.direction = -state.direction; 
        end
        
        
        if state.direction == 1
            state.currentPos = state.currentPos + elevatorSpeed;
            set(statusText, 'String', 'Status: GOING UP (SCAN)');
        else
            state.currentPos = state.currentPos - elevatorSpeed;
            set(statusText, 'String', 'Status: GOING DOWN (SCAN)');
        end
        
        state.currentPos = max(0, min(4, state.currentPos));
    end
end