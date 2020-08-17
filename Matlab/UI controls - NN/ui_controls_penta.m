%**************************************************************************
%                            TESIS DE GRADO
%                               EEG v1.0
%                   Instituto de Ingenieria Biomédica
%           Facultad de Ingenieria, Universidad de Buenos Aires
%
%                           Florencia Grosso
%                      Tutor: Dr. Ing. Sergio Lew
%
%  Code description:
%  This file contains the code for the EOG based BCI's GUI. It handles the
%  live testing algorithm, which includes:
% 
%   - Displaying telop-like user interface with buttons indicating a
%     movement action (forward, backwards, turn left & turn right).
%   - Presentating stimuli audios in random order at a given rate.
%   - Storing stimuli data (coordinates, ts, control index).
%   - Recording eog data.
%   - Predicting focal point, mapping it to the corresponding control
%     (if any).
%   - Signaling the predicted action.
%   - Detecting and signaling a confirmed action.
%   - Storing prediction data (coordinates, ts, control index).
%  
%**************************************************************************
function varargout = ui_controls_penta(varargin)
% UI_CONTROLS_PENTA M-file for dot_generator.fig
%      UI_CONTROLS_PENTA, by itself, creates a new UI_CONTROLS_PENTA or raises the existing
%      singleton*.
%
%      H = UI_CONTROLS_PENTA returns the handle to a new UI_CONTROLS_PENTA or the handle to
%      the existing singleton*.
%
%      UI_CONTROLS_PENTA('Property','Value',...) creates a new UI_CONTROLS_PENTA using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to dot_generator_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      INPUT ARGUMENTS ARE:
%           1) seconds per stimuli
%           2) number of stimuli to display
%           3) serial port object (where device is connected) 
%           4) number of active/on eeg channels (eog = 2)
%           5) initial signal amplification done by the ADS1299
%           6) sampling rate of ADS1299's output
%           7) number of past samples to use when computing the signal derivative
%           8) amplitude threshold for blinks
%           9) test id for output filename
%
%      UI_CONTROLS_PENTA('CALLBACK') and UI_CONTROLS_PENTA('CALLBACK',hObject,...) call the
%      local function named CALLBACK in UI_CONTROLS_PENTA.M with the given input
%      arguments.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @ui_controls_penta_OpeningFcn, ...
                   'gui_OutputFcn',  @ui_controls_penta_OutputFcn, ...
                   'gui_LayoutFcn',  [], ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
   gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before ui_controls_penta is made visible.
function ui_controls_penta_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for dot_generator
% handles object
handles.output = hObject;

%% STORE INPUT ARGS IN THE HANDLES OBJECT
% Seconds per stimuli
period =  varargin{1};
% Number of stimuli to display
handles.N_total = varargin{2};
% Serial port object
handles.serial_port = varargin{3};
% Number of eeg active channels (eog = 2)
handles.active_channels = varargin{4};
% Initial signal amplification done by the ADS1299.
handles.arduino_gain = varargin{5};
% Sampling rate of ADS1299's output.
handles.fs = varargin{6};
% Number of past samples to use when computing the signal derivative.
handles.n_derivative = varargin{7};
% Max valid value for CH2 data. Higher values are considered blinks.
handles.blinks_thr = varargin{8};
% id used to save pytorch params
test_id = varargin{9};
% Test stimuli file: saves data for each stimuli presented as a matrix,
% where each row contains [stimuli_x stimuli_y ts ctrl_idx]
handles.stimuli_file_name = strcat('../data/', test_id, '_test.mat');
% File id where to save eeg data to
handles.output_file_id = fopen(strcat('../data/', test_id, '_test.txt'),'w');
% Cal stimuli file: saves data for each focal point predicted as a matrix,
% where each row contains
% [stimuli_number pred_x pred_y ts button_x_idx button_y_idx button_numeric_idx]
handles.pred_file_name = strcat('../data/', test_id, '_pred.mat');

%% CUSTOMIZE CONTROL BUTTONS WITH A BACKGROUND IMAGE

% Control references are:
% C1 = UP / FORWARD
% C2 = TURN RIGHT
% C3 = DOWN / BACKWARDS
% C4 = TURN LEFT


% UP control - DEFAULT
a = imread('right.png');
[r,c,d]=size(a); 
x=ceil(r/500); 
y=ceil(c/500); 
C1_img_default=a(1:x:end,1:y:end,:);
C1_img_default(C1_img_default == 255) = 5.5 * 255;

% UP control - FOCUSED
a = imread('right_foc.png');
C1_img_focused=a(1:x:end,1:y:end,:);
C1_img_focused(C1_img_focused == 255) = 5.5 * 255;

% TURN RIGHT control - DEFAULT
a = imread('down.png');
C2_img_default=a(1:x:end,1:y:end,:);
C2_img_default(C2_img_default == 255) = 5.5 * 255;

% TURN RIGHT control - FOCUSED
a = imread('down_foc.png');
C2_img_focused=a(1:x:end,1:y:end,:);
C2_img_focused(C2_img_focused == 255) = 5.5 * 255;

% BACK control - DEFAULT
a = imread('left.png');
C3_img_default=a(1:x:end,1:y:end,:);
C3_img_default(C3_img_default == 255) = 5.5 * 255;

% BACK control - FOCUSED
a = imread('left_foc.png');
C3_img_focused=a(1:x:end,1:y:end,:);
C3_img_focused(C3_img_focused==255) = 5.5 * 255;

% TURN LEFT control - DEFAULT
a = imread('up.png');
C4_img_default=a(1:x:end,1:y:end,:);
C4_img_default(C4_img_default == 255) = 5.5 * 255;

% TURN LEFT control - FOCUSED
a = imread('up_foc.png');
C4_img_focused=a(1:x:end,1:y:end,:);
C4_img_focused(C4_img_focused == 255) = 5.5 * 255;

% RECALIBRATION point - DEFAULT
a = imread('recal.png');
X_img_default=a(1:x:end,1:y:end,:);
X_img_default(X_img_default == 255) = 5.5 * 255;

% RECALIBRATION point - FOCUSED
a = imread('recal_foc.png');
X_img_focused=a(1:x:end,1:y:end,:);
X_img_focused(X_img_focused == 255) = 5.5 * 255;

% CONTROL SELECTED
a = imread('selected.png');
C_img_selected=a(1:x:end,1:y:end,:);
C_img_selected(C_img_selected == 255) = 5.5 * 255;

% Set default icons for all controls
set(handles.C1,'CData',C1_img_default);
set(handles.C2,'CData',C2_img_default);
set(handles.C3,'CData',C3_img_default);
set(handles.C4,'CData',C4_img_default);

% Save icons on handles
handles.C1_img_default = C1_img_default;
handles.C1_img_focused = C1_img_focused;
handles.C2_img_default = C2_img_default;
handles.C2_img_focused = C2_img_focused;
handles.C3_img_default = C3_img_default;
handles.C3_img_focused = C3_img_focused;
handles.C4_img_default = C4_img_default;
handles.C4_img_focused = C4_img_focused;
handles.C_img_selected = C_img_selected;

% RECALIBRATION point
set(handles.X,'CData',X_img_default);
handles.X_img_default = X_img_default;
handles.X_img_focused = X_img_focused;

% Remove borders for recalibration control
jEdit = findjobj(handles.X);
lineColor = java.awt.Color(0,0,0);  % =black
thickness = 3;  % pixels
roundedCorners = true;
newBorder = javax.swing.border.LineBorder(lineColor,thickness,roundedCorners);
jEdit.Border = newBorder;
jEdit.repaint;  % redraw the modified control

%% COMMANDS

% Audio recordings for the commands
[y1, Fs1] = audioread('right.mp3');         %C1
[y2, Fs2] = audioread('backward.mp3');      %C2
[y3, Fs3] = audioread('left.mp3');          %C3
[y4, Fs4] = audioread('forward.mp3');       %C4

handles.audio_C1 = y1;
handles.audio_C2 = y2;
handles.audio_C3 = y3;
handles.audio_C4 = y4;
handles.audio_fs = Fs1;

% Coordinates of center of controls
handles.ctrls = [[0.5 0.832];   %C1
                 [0.9 0.495];   %C2
                 [0.5 0.165];   %C3
                 [0.1 0.495]];  %C4
            
% Button's dimensions (in normalized screen scale)
handles.x_res = 0.2;
handles.y_res = 0.3333333333;

%% INITIALIZE SEQUENCE VARS

% ID of last button selected
handles.last_button = 'C1';
% ID of button corresponding to the current stimuli
handles.stimuli_button = '';

% Flag to indicate whether the first stimuli was already displayed or not.
% This is used to avoid getting stuck on the very first render and advance
% properly to the following cycles.
handles.displayed = false;

% Array of accumulated stimuli positions for the test
handles.stimuli_position = [];
% Internal cycles counter
handles.N = 0;
% Flag to indicate whether the current cycle is a calibration or not
handles.calibration_on = false;
% [x y] prediction
handles.pred = [0.5 0.5];

% Matrices to use when computing the NN's prediction
handles.w1 = csvread(strcat('..\..\Pytorch\output\w1_', test_id, '.txt'));
handles.w2 = csvread(strcat('..\..\Pytorch\output\w2_', test_id, '.txt'));
handles.bias1 = csvread(strcat('..\..\Pytorch\output\bias1_', test_id, '.txt'));
handles.bias2 = csvread(strcat('..\..\Pytorch\output\bias2_', test_id, '.txt'));

%% TIMER OBJECTS
% Initiate timer and callback function:
handles.timer = timer('ExecutionMode', ...
                      'fixedSpacing',....
                      'TasksToExecute', handles.N_total, ...
                      'Period', period, ...
                      'TimerFcn',{@timerCallback, hObject});
handles.timer.StopFcn = {@timerStopCallback, hObject};

% Update handles structure
guidata(hObject, handles);
start(handles.timer);

% Timer callback: It will be triggered when a new stimuli needs to be
% rendered.
function timerCallback(~, ~, parent_GUI)
% Calibration parameters
cal_spacing = 4; % Calibrate every 4 stimuli
% Sequence in which calibration will be prompted
calibration = 0:cal_spacing:99;
% Coordinates of the calibration point
cal_xy = [ 0.5 0.5 ]; % Use the center of the screen for now

% Get updated handles data
handles = guidata(parent_GUI);

% Clean previous calibration
set(handles.X,'Visible','off');

handles.confirmation_on = false;

% % Clean up previous stim -> set img back to default
% if ~ isempty(handles.stimuli_button)
%       set(eval(strcat('handles.', handles.stimuli_button)),'CData', eval(strcat('handles.', handles.stimuli_button, '_img_default')));
% end

% If cycle number is within calibration program and calibrate flag is on,
% proceed with the calibration sequence.
if ismember(handles.N, calibration)
    % Calibration bell
    res = 100050;
    len = 0.5 * res;
    sound( sin( 500*(2*pi*(0:len)/res) ), res);
    
    % Display calibration control
    set(handles.X,'Visible','on');
    
    % Turn on flag to indicate we are calibrating
    handles.calibration_on = true;

    ctrl_idx = 0;
    stimuli_pos = cal_xy;
else
    % Turn off calibration flag
    handles.calibration_on = false;
    
    guidata(parent_GUI, handles);
    
    % Get the index of the control that will be presented randomly (1, 2,
    % 3, 4)
    ctrl_idx = randi(length(handles.ctrls));
    
    % Label of the button for the ctrl presented (C1, C2, C3, C4)
    button_label = strcat('C', string(ctrl_idx));   
    % Save it gobally
    handles.stimuli_button = button_label;
    
    % Map control id to screen coordinates
    stimuli_pos = handles.ctrls(ctrl_idx, :);
    
    % Reproduce audio with stimuli
    sound(eval(strcat('handles.audio_', handles.stimuli_button)), handles.audio_fs);  
end

% Save the button's data to handles (coordinates, ts and control id)
handles.stimuli_position = [handles.stimuli_position; [stimuli_pos now ctrl_idx]];

% Increase total timer
% NOTE: this is independent of the type of stimuli shown (test or
% calibration)
handles.N = handles.N +1;

% Update handles data so that other threads can use it
guidata(parent_GUI, handles);

% Timer stop callback: It will be triggered once all stimuli are presented.
% Saves stimuli data to output file.
function timerStopCallback(~, ~, parent_GUI)
handles = guidata(parent_GUI);
stimuli_position = handles.stimuli_position;

% Save the array of stimuli positions, ts and data type indicators to a
% .mat file
save(handles.stimuli_file_name,'stimuli_position');

% Main method. Reads data continuously and processes it to get the
% predicted control selections. 
function varargout = ui_controls_penta_OutputFcn(hObject, eventdata, handles)
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Make guide fill window, with normalized screen units (0...1 for both
% directions)
set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
drawnow;

% Maximize figure to fill screen
jFig = get(handle(gcf), 'JavaFrame'); 
jFig.setMaximized(true);
% Get default command line output from handles structure
varargout{1} = handles.output;

% Array of peaks detected during the test. This is a matrix with 2 columns,
% one per channel.
accum_peaks = [];
% Data read on last cycle. M x 2 column.
last_c = [];

% Accumulated errors for each channel, obtained by calibrating the
% measurements with a stimuli placed at the center of the screen.
% Note that after every re-calibration this is set back to (0,0).
zero_drift = [0 0];

% Number of points from the last cycle to use when computing the signal's
% derivative.
n_derivative = handles.n_derivative;

% EEG samples to read on each cycle
samples = handles.fs * 2;

% Update handles data
handles = guidata(hObject);

% Array of predicted data, accumulated through the test. Each row contains
%[x y] information.
pred_array = [];

% Clean serial port before the test
flushinput(handles.serial_port)
flushoutput(handles.serial_port)

% Selected button index
button_idx = 'none'; % Start with a value not matching any of the controls.
button_numeric_idx = 99;
last_cmd_confirmed = false;

% Main loop to read data from eeg device. Run continuously until stimuli
% render is complete.
while handles.N < handles.N_total  
    handles = guidata(hObject);
    
    % Read channel data from port
    c = fread(handles.serial_port, samples, 'float');
    
    % If there's already accumulated data, start processing new inputs
    % (this is because of the derivative filter)
    if length(last_c) > 1        
        % The last focused button is the last saved button idx
        last_button = button_idx;
        
        % Split channels and filter signal
        [raw_data, filtered_data, peaks, double_click] = process_live_data(...
            [last_c(end - ( 2 * n_derivative - 1 ):end); c],...
            handles.active_channels,...
            handles.arduino_gain,...
            handles.fs,...
            n_derivative,...
            handles.blinks_thr);
        disp 'HERE3'
         
        % User confirmed the stimuli
        if double_click && ~handles.calibration_on
            disp 'RENDERING CONFIRMATION'
            % There was a double click, skip all data processing
            % Mark the last focused button as selected
            if ~strcmp(last_button, 'none')
                confirmation_on = true;
                handles.confirmation_on = true;
                set(eval(strcat('handles.', last_button)),'CData',eval(strcat('handles.C_img_selected')));
                pred_array = [pred_array; [handles.N [0 0] [0 0] now 0 0 button_numeric_idx double_click]];
                last_cmd_confirmed = true;
            end
        end
                 
        if handles.confirmation_on == true
            disp 'HERE'
%             guidata(hObject, handles);
            continue
        end
        
        disp 'HERE2'
            
        % Invert peaks for the rotated screen. This means that:
        % screen's x maps to -CH2 (vertical)
        % screen's y maps to CH1 (horizontal)
        % peaks2 = [-peaks(:, 2), peaks(:, 1)];
        % Accumulate calculated peaks
        accum_peaks = [accum_peaks; peaks];
        
        % The current position is the sum of the accumulated peaks
        current_pos_raw = sum(accum_peaks, 1);
        
        % We are calibrating. The recording points to the zero drift.
        if handles.calibration_on
            zero_drift = current_pos_raw;
        end
        
        % Corrected position: remove zero drift
        current_pos_corrected = current_pos_raw - zero_drift;
        
        % Now take it to 0...1
        pred = get_nn_prediction(current_pos_corrected, ...
                                 handles.w1, handles.w2, ...
                                 handles.bias1, ...
                                 handles.bias2);
        % In case the calculation makes the value fall out of the screen
        for k=1:length(pred)
            if pred(k) < 0 || pred(k) > 1
                disp(strcat('Predicted values out of bounds: ', num2str(pred(k))));
                pred = max(min(pred(k), 1), 0);
            end
        end
        
        % Map button coordinates to its x and y idxs on screen, using
        % its dimensions.
        button_x_idx = max(floor(pred(1)/0.1), 1);
        button_y_idx = max(ceil(pred(2)/handles.y_res), 1);

        % Get the id of the selected button.
        if button_x_idx >= 0 && button_x_idx < 2
            if button_y_idx == 2
                button_idx = 'C4';
                button_numeric_idx = 4;
            end
        elseif button_x_idx >= 4 && button_x_idx < 6
            if button_y_idx == 1
                button_idx = 'C3';
                button_numeric_idx = 3;
            elseif button_y_idx == 2
                button_idx = 'X';
                button_numeric_idx = 0;
            elseif button_y_idx == 3
                button_idx = 'C1';
                button_numeric_idx = 1;
            end
        elseif button_x_idx >= 8 && button_x_idx < 10
            if button_y_idx == 2
                button_idx = 'C2';
                button_numeric_idx = 2;
            end
        else
            % The idxs don't map to any of the available buttons. None was
            % selected.
            button_idx = 'none';
            button_numeric_idx = 99;
        end
        
        if ~strcmp(last_button, button_idx) %|| last_cmd_confirmed == true
            % Deselect the last selected button
            if ~strcmp(last_button, 'none')
                set(eval(strcat('handles.', last_button)),'CData',eval(strcat('handles.', last_button, '_img_default')));
            end
            % Update selection with the current prediction
            if ~strcmp(button_idx, 'none')
                set(eval(strcat('handles.', button_idx)),'CData',eval(strcat('handles.', button_idx, '_img_focused')));
            end
        end        
               
%         guidata(hObject, handles);
                
        % Accumulate prediction data
        pred_array = [pred_array; [handles.N current_pos_corrected pred now button_x_idx button_y_idx button_numeric_idx double_click]];
    end
    drawnow;
    
    % Store last channel data for next derivative calculation
    last_c = c;
    
    % Output channel data to file
    fprintf(handles.output_file_id, '%f\n', c);
end

% Test is finished. Save prediction data to handles.
save(handles.pred_file_name,'pred_array');

% Reading is over. Close port and data files.
fclose(handles.output_file_id);
fclose(handles.serial_port);

% Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);
