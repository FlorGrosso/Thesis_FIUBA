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
%  This is the main block for calibration data processing. It performs the 
%  following operations:
%       - Loads recorded EOG data, raw.
%       - Splits channel data according to n° of active channels.
%       - Computes signal derivative.       
%       - Removes outliers (HF peaks mostly due to blink artifacts) as well
%       as low amplitude noise.
%       - Computes the voltage variation in response to a stimuli
%       presented on screen.
% 
%  INPUTS args:
%   - cal_output: file id containing raw eog data from the calibration
%   process.
%   - n_cal: number of calibration cycles executed.
%   - t_cal: seconds between consecutive stimuli.
%   - n_der: number of past samples to use when computing the signal
%     derivative.
%   - fs: sampling rate of eog signal.
%   - arduino_gain: initial signal amplification done by the ADS1299.
%
%  OUTPUT:
%   - channel_data: raw eog data, separated by channel.
%   - sf: derived and filtered channel_data.
%   - peaks: matrix of detected voltage peaks for each channel. This should
%   be of the same length as n_cal, as there is one peak per stimuli
%   window.
%**************************************************************************

function [channel_data, sf, peaks] = process_calibration_data(cal_output, n_cal, t_cal, n_der, fs, arduino_gain)
active_channels = 2;

% Samples per window
spw = 2 * t_cal * fs + 2 * fs;
% Total samples to process
tsp = n_cal * spw;

% Read eog data from calibration
file_id = fopen(cal_output,'r');
eeg_data = fscanf(file_id,'%f');
fclose(file_id);

% Noise floor [ch1 ch2]. Values below the limits will be removed.
noise_lim_low = [ 80 80 ];
% Signal ceiling [ch1 ch2]. Values above the limits will be removed.
noise_lim_high = [ inf 250 ]; % ch1 is almost immune to blinkings.

% Separate eeg data per channel. The result is an M x 2 matrix, with
% recorded data processed to obtain real value (arduino gain is undone).
channel_data = split_channels(eeg_data, active_channels, arduino_gain);

% Get amplitude of each eog stimuli by applying a manual filter to the raw
% signal (takes derivative using n preceding samples to the current one)
for i=1:active_channels
    s = channel_data(:,i);
    
    % Derivative of raw signal
    sd = s(n_der+1:end) - s(1:end-n_der);
    
    % [OPTIONAL] Plot signal derivative vs time per channel
    time = 0:1/fs:length(sd)/fs - 1/fs;
    figure
    plot(sd);
    xlabel('Time [s]');
    ylabel('Amplitude [\muV]');
    title(strcat('CH', num2str(i), ' - Signal derivative, raw'));
    
    % Remove noise floor as well as high aplitude blinks noise
    idxs = find(abs(sd) > noise_lim_low(i) & abs(sd) < noise_lim_high(i)); 
    sf(:,i) = zeros(length(sd), 1); 
    sf(idxs, i) = sd(idxs); % signal filtered
    
    % Windows counter
    k = 1;
    % Process each window to get the corresponding peak. Shift processing
    % start to capture intervals between stimuli completely.
    for j = 750 : spw : tsp
        % Get absolute max and min for each peak.
        [peak1, idx1] = max(sf(j:j + spw/2,i));
        [peak2, idx2] = min(sf(j:j + spw/2,i));
        
        % Peaks are close (less than 100 samples apart) so its either
        % a blink or overshoot on an edge. Add them to counteract the
        % effect.
        if abs(idx1 - idx2) < 100        
             peak_x = peak1 + peak2;
             if abs(peak_x) < noise_lim_low(i)
                 peak_x = 0;
             end
             peaks(k,i) = peak_x;
        else
            % Check which peak (max or min) has the highest absolute value.
            % That will be selected as the window's peak.
            if abs(peak1) > abs(peak2)
                peaks(k,i) = peak1;
            elseif abs(peak1) < abs(peak2)
                peaks(k,i) = peak2;
            else
                peaks(k,i) = 0;
            end
        end
        
        if i == 2
            if abs(peaks(k, i)) > 0 && abs(peaks(k, 1)) > 0
                peaks(k, 1) = 0;
            end
        end
        % Increase windows count.
        k= k + 1;
    end
    
end

% Remove first n samples, used to compute derivative only
channel_data = channel_data(n_der + 1:end, :);
end