%**************************************************************************
%                            TESIS DE GRADO
%                               EEG v1.0
%                   Instituto de Ingeniería Biomédica
%           Facultad de Ingeniería, Universidad de Buenos Aires
%
%                           Florencia Grosso
%                      Tutor: Dr. Ing. Sergio Lew
%
%  Code description:
%  This file contains the code for the calibrator GUI. It handles the:
%
%   - Presentation of stimuli in random order at a given rate.
%   - Storage of stimuli data (coordinates, ts, control index).
%  
%**************************************************************************

function varargout = calibrator_gui(varargin)
% CALIBRATOR_GUI M-file for calibrator_gui.fig
%      CALIBRATOR_GUI, by itself, creates a new CALIBRATOR_GUI or raises the existing
%      singleton*.
%
%      H = CALIBRATOR_GUI returns the handle to a new CALIBRATOR_GUI or the handle to
%      the existing singleton*.
%
%      CALIBRATOR_GUI('Property','Value',...) creates a new CALIBRATOR_GUI using the
%      given property value pairs. Unrecognized properties are passed via
%      varargin to calibrator_gui_OpeningFcn.  This calling syntax produces a
%      warning when there is an existing singleton*.
%
%      INPUT ARGUMENTS ARE:
%           1) seconds per stimuli
%           2) number of stimuli to display
%           3) filename where to save stimuli position and ts
%
%      CALIBRATOR_GUI('CALLBACK') and CALIBRATOR_GUI('CALLBACK',hObject,...) call the
%      local function named CALLBACK in CALIBRATOR_GUI.M with the given input
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
                   'gui_OpeningFcn', @calibrator_gui_OpeningFcn, ...
                   'gui_OutputFcn',  @calibrator_gui_OutputFcn, ...
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

% --- Executes just before calibrator_gui is made visible.
function calibrator_gui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   unrecognized PropertyName/PropertyValue pairs from the
%            command line (see VARARGIN)

% Choose default command line output for calibrator_gui
% Seconds per stimuli
period =  varargin{1};
% Number of stimuli to display
handles.N_total = varargin{2};
% Filename where to save stimuli position and ts
handles.output_file_name = varargin{3};

% Stimuli count
handles.N = 1;
% Matrix containing stimuli information on each row:
% [ stimuli_x stimuli_y button_idx ts ]
handles.stimuli_position = [];
handles.output = hObject;
handles.displayed = false;

% CALIBRATION SECUENCE
% HORIZONTAL + VERTICAL CHANNEL:
% Points that calibration should cover 
% (LEFT)        (CENTER)        (RIGHT)
% ----------------> X <----------------
% -------------------------------------
% X <-------------> X <-------------> X
% -------------------------------------
% ----------------> X <----------------

% NOTE that the center is a mandatory position between each of these points
% (odds go to (0.5, 0.4950))

% Stimuli # for each position
cal_points = [ [ 0.50 0.4950 ];     % X,  id: 1
               [ 0.50 0.8250 ];     % C1, id: 2
               [ 0.90 0.4950 ];     % C2, id: 3
               [ 0.50 0.1650 ];     % C3, id: 4
               [ 0.10 0.4950 ]];    % C4, id: 5    

% Order of stimuli to present, reshuffled 
handles.current_seq = randperm(length(cal_points));
handles.cal_points = cal_points(handles.current_seq,:);

handles.center_N = 1:2:(2*length(cal_points)+1);
handles.total_cal = length(cal_points) + length(handles.center_N);

% Initiate timer and callback function:
handles.timer = timer('ExecutionMode', 'fixedSpacing', 'TasksToExecute', handles.N_total, 'Period', period,'TimerFcn',{@timerCallback, hObject});
handles.timer.StopFcn = {@timerStopCallback, hObject};

% Update handles structure
guidata(hObject, handles);
start(handles.timer);

% Timer callback: It will be triggered when a new stimuli needs to be
% rendered.
function timerCallback(~, ~, parent_GUI)

handles = guidata(parent_GUI); 

% Clean previous 'X'
set(handles.X,'Visible','off');

% Initial rendering. Needed to avoid losing start screen.
if ~handles.displayed
    dot_xy = [0.5 0.4950];
    handles.displayed = true;
end

% Assign the corresponding calibration position to the marker on the
% screen.
if handles.N <= handles.total_cal
    % Odd stimuli count needs to be mapped to the center of the screen.
    % Even stimuli count present a value from the random sequence.
    if mod(handles.N, 2) == 1
        dot_xy = [ 0.5 0.4950 ];
        ctrl_idx = 0;
    else
        dot_xy = handles.cal_points(handles.N/2, :);
        ctrl_idx = handles.current_seq(handles.N/2);
    end
end

% Increase stimuli count
% NOTE: this is independent of the type of stimuli shown (test or
% calibration)
handles.N = handles.N +1;

dot_position = [dot_xy 0.033 0.073]; % [x y button_width button_height]
% Display stimuli / reference on screen
set(handles.X,'Visible','on', 'Position', dot_position);
drawnow;

% Accumulate stimuli data
handles.stimuli_position = [handles.stimuli_position; [dot_xy now ctrl_idx]];

% Update handles structure
guidata(parent_GUI, handles);

% Timer stop callback: It will be triggered once all stimuli are presented.
% Saves stimuli data to output file.
function timerStopCallback(~, ~, parent_GUI)
handles = guidata(parent_GUI);
stimuli_position = handles.stimuli_position;

% Save stimuli info to a mat file
save(handles.output_file_name,'stimuli_position');

% Outputs from this function are returned to the command line.
function varargout = calibrator_gui_OutputFcn(hObject, eventdata, handles)
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
set(gcf, 'units','normalized','outerposition',[0 0 1 1]);
drawnow;
% Maximize figure
jFig = get(handle(gcf), 'JavaFrame'); 
jFig.setMaximized(true);
% Get default command line output from handles structure
varargout{1} = handles.output;

% Executes when user attempts to close figure1.
function figure1_CloseRequestFcn(hObject, eventdata, handles)
% hObject    handle to figure1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hint: delete(hObject) closes the figure
delete(hObject);
