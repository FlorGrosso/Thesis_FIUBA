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
%  Main script for the EOG based BCI. It is the entry point to execute the
%  following stages:
%    1. Calibration
%       - Presents the calibration interface
%       - Records eog data from vertical & horizontal channel and stores
%       them into a file
%       - Processes the data to extract the features to train the NN (input
%       & desired output).
%    2. Training of the NN
%       - Calls the pytorch script that trains the network. 
%    3. Live test
%       - Presents the testing interface, which reads and processes data
%       continuously, online.
%
%  As the entry point, this script also manages the serial port and the
%  files where all the recorded / generated data will be stored.
%
%**************************************************************************

close all
clear

%% CONSTANTS
samples = 500;

% Seconds between consecutive stimuli
seconds_per_stimuli_cal = 4; % Calibration 
seconds_per_stimuli_test = 8; % Live test

% Number of past samples to use when computing the signal derivative
% according to: e'(t) = e(t) - e(t - n)
n_derivative = 50;

% Flags to enable/disable calibration and live testing execution.
calibration_on = true;
testing_on = true;

% Flag that indicate whether to save captured data into files.
save_data_to_file = true;

% Number of stimuli to present on live test
N_test_stimuli = 30;

% EOG specific
active_channels = 2;

% ADS1299 config params
arduino_gain = 24;
fs = 250;

%% OUTPUT FILES SET UP

% Create files to save data to. Make the names out of the user name + 
% current date, to avoid stepping them over.

% User data
name = 'Florencia';
surname = 'Grosso';

% If we are calibrating, we'll need to make up a new file name for all data
if calibration_on
    current_date = datestr(now, 'dd_mm_yyyy_HH_MM_SS');
else
    % Fixed date in case we skip calibration (reusing params)
    current_date = '09_08_2020_15_57_24'%'09_08_2020_13_16_53'%'09_08_2020_11_05_05'%'08_08_2020_16_37_10'%'08_08_2020_14_01_08';
end

test_id = strcat(name, '_', surname, '_', current_date);

% CALIBRATION
% File to store data for the presented stimuli
% Cal stimuli file: saves data for each stimuli presented as a matrix,
% where each row contains (check calibrator_gui.m)
% [stimuli_x stimuli_y ts ctrl_idx]
cal_stimuli_file_name = strcat('../data/', test_id, '_cal.mat');

% Files to store raw EOG data to
cal_eeg_file_name = strcat('../data/', test_id, '_cal.txt');
% Only open a calibration file if we are including a calibration stage. If
% not, this has the risk of stepping over a valid calibration file.
if calibration_on
    cal_eeg_file_id = fopen(cal_eeg_file_name,'w');
end

% NEURAL NETWORKS
nn_python_script = '../../Pytorch/pytorch_nn.py ';

% Files to share with Pytorch
% Original data
nn_input_file = strcat('../../Pytorch/input_data/input_', test_id,'.txt');
nn_output_file = strcat('../../Pytorch/input_data/output_', test_id,'.txt');
% Inflated data
nn_input_file_filled = strcat('../../Pytorch/input_data/input_', test_id,'_filled.txt');
nn_output_file_filled = strcat('../../Pytorch/input_data/output_', test_id,'_filled.txt');

%% SERIAL PORT

% Delete all serial port objects
delete(instrfindall)

% Create a serial port associated with COM3
s = 'COM3';
serial_port = serial(s);
serial_port.BaudRate = 115200;
serial_port.DataBits = 8; 
serial_port.Parity = 'none';
serial_port.StopBits = 1;
serial_port.inputBufferSize = 2056;

% Perform serial port clean up
fopen(serial_port)
pause(6)
flushinput(serial_port)
flushoutput(serial_port)
pause(1)
fwrite(serial_port,'1');
pause(1)

%% CALIBRATION STAGE

if calibration_on
    % CONFIG
    % Configuration for the dot displacing screen
    current_cycle = 0;
    N_dots = 12;
    calibration_cycles = (N_dots + 4) * seconds_per_stimuli_cal;
    
    % Initial bell
    res = 100050;
    len = 0.5 * res;
    sound( sin( 400*(2*pi*(0:len)/res) ), res);
    
    while(current_cycle < calibration_cycles)
        % On first pass, clean the port and open the calibrator GUI
        if current_cycle == 0
            flushinput(serial_port)
            flushoutput(serial_port)
            % Calibrator GUI
            cal_gui = calibrator_gui(seconds_per_stimuli_cal,...
                N_dots,...
                cal_stimuli_file_name);
            cal_fig = figure(cal_gui);
        end
        
        % Read samples from serial port
        c = fread(serial_port, samples, 'float')
        
        % Print channel data to file
        fprintf(cal_eeg_file_id, '%f\n', c);
        
        % Update cycles count
        current_cycle = current_cycle + 1;
    end
    
    close all;
    
    % Close file with calibration data
    fclose(cal_eeg_file_id);
end

%% PROCESS DATA AND GET CALIBRATION PARAMETERS

if calibration_on
    % raw_signal: N x 2 matrix containing eeg signals, separated by channel
    % derivative: M x 2 signal derivative, separated by channel
    % peaks: 5 x 2 matrix with voltage peaks linked to stimuli, separated by channel 
    [raw_signal, derivative, peaks] = process_calibration_data(cal_eeg_file_name,...
        5,...
        seconds_per_stimuli_cal,...
        n_derivative,...
        fs,...
        arduino_gain);
    
    %[OPTIONAL] plot raw, derived and peaks from calibration signals
    plot_calibration_data(raw_signal, derivative, peaks);
    
    %peaks = [-peaks(:, 2), peaks(:, 1)];

    % Save training data to files
    if save_data_to_file
        csvwrite(nn_input_file, peaks);
    
        % Calibration data is a matrix, where each row includes:
        % [stim_x stim_y stim_number ts]
        % First, we need only (x, y) data
        cal_data_full = load(cal_stimuli_file_name);
        cal_stimuli_full = cal_data_full.stimuli_position(:, 1:2);
        
        % Then, remove extra rows corresponding to default returns to the
        % center of the screen. Those happen right before every stimuli.
        cal_stimuli = cal_stimuli_full(2:2:end, :);
        
        csvwrite(nn_output_file, cal_stimuli);
        
        % Stop code execution to take a look at calibration values
        keyboard;
        % Reshuffle data to have it ordered as: X, C1, C2, C3, C4
        stimuli_order_full = cal_data_full.stimuli_position(:, 4);
        stimuli_order = stimuli_order_full(2:2:end, :);        
        peaks_reshuffled = peaks(stimuli_order, :);
        cal_stimuli_reshuffled = cal_stimuli(stimuli_order, :);
        
        % Get max span for y axis
        y_exc = 2 * max(abs(peaks(:,2)));
        
        % Additional points to add per stimuli.
        noise_per_stim = 39;
        
        % Add noise to registered data to fill the nn input with more
        % samples that cover each control's surface.
        [peaks_filled, cal_stimuli_filled] = noise_adder(peaks_reshuffled, cal_stimuli_reshuffled, noise_per_stim);
        
        % Save filled data
        csvwrite(nn_input_file_filled, peaks_filled);
        csvwrite(nn_output_file_filled, cal_stimuli_filled);
    end
end

%% NEURAL NETWORK

% Run the python script that trains the neural network with calibration
% values.
if calibration_on
    systemCommand = ['python ', nn_python_script, ' ', test_id];
    [status, result] = system(systemCommand);
end

%% Get calibration values
% NOTE: this is computed manually, observing the calibration output from
% above. Consider automating this properly.

if exist('y_exc', 'var')
    blinks_thr = 1.2 * y_exc;
else
    % Default value
    blinks_thr = 500;
end
    
%% LIVE TEST

% Initial bell
res = 100050;
len = 0.5 * res;
sound( sin( 400*(2*pi*(0:len)/res) ), res);

if testing_on
    % Open testing GUI    
    gui = ui_controls_penta(seconds_per_stimuli_test,...
        N_test_stimuli,...
        serial_port,...
        active_channels,...
        arduino_gain,...
        fs,...
        n_derivative,...
        blinks_thr,...
        test_id);
    h = figure(gui);
    
    % Wait until the test is finished to close the serial port
    while strcmp(serial_port.Status, 'open')
        sleep(5)
    end
    
    delete(instrfindall);
    
    % Final bell
    disp('Finished recording');

    close all;
end
