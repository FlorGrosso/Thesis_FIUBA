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
%  This is the main block for data processing during the EOG live test. It 
%  performs the  following operations:
%       - Splits channel data according to n° of active channels.
%       - Computes signal derivative.       
%       - Removes outliers (HF peaks mostly due to blink artifacts) as well
%       as low amplitude noise.
%       - Computes the voltage variation in response to a stimuli
%       presented on screen.
%       - Checks for user confirmation signals (double click/blink).
% 
%  INPUTS args:
%   - eeg_output: raw block of eog data from the (1 second of samples per
%     channel).
%   - active_channels: number of active/on eeg channels (eog = 2).
%   - arduino_gain: initial signal amplification done by the ADS1299.
%   - fs: sampling rate of eog signal.
%   - n_der: number of past samples to use when computing the signal
%     derivative.
%   - abs_peak_max: higher limit for signal peaks (values higher than these
%     are linked to overshooting and thus filtered).
%
%  OUTPUT:
%   - channel_data: raw eog data, separated by channel.
%   - sf: derived and filtered channel_data.
%   - peaks: matrix of detected voltage peaks for each channel. This should
%     be of the same length as n_cal, as there is one peak per stimuli
%     window.
%   - double_click: flag indicating whether a double click was detected.
%**************************************************************************

function [channel_data, sf, peaks, double_click] = process_live_data(eeg_output, active_channels, arduino_gain, fs, n_der, abs_peak_max)
% Separate eeg data per channel. The result is an M x 2 matrix, with
% recorded data processed to obtain real value (arduino gain is undone).
channel_data = split_channels(eeg_output, active_channels, arduino_gain);

% Noise floor [ch1 ch2]. Values below the limits will be removed.
noise_lim = [ 100 80 ];

double_click = false;

% Notch filter at 50 Hz
wo=50/(250/2);bw=wo/5;
[bn,an]=iirnotch(wo,bw);

data_notch = filter(bn, an, channel_data);

% Get amplitude of each eog stimuli by applying a manual filter to the raw
% signal (takes derivative using n preceding samples to the current one)
for i=1:active_channels
    s = channel_data(:,i);
       
    % Derivative of raw signal
    sd= s(n_der + 1:end) - s(1:end - n_der);
    %     disp('S')
    %     length(s)
    %     disp('SD')
    %     length(sd)
    
    % Remove noise floor
    idxs = find(abs(sd) > noise_lim(i));
    sf(:,i) = zeros(length(sd), 1);
    %     disp('SF')
    %     length(sf)
    sf(idxs, i) = sd(idxs);
    
    % Get absolutes max and min for this window.
    [peak_max, idx_peak_max] = max(sf(:,i));
    [peak_min, idx_peak_min] = min(sf(:,i));
    
    % Check for outliers
    % Check if the + peak is higher than the highest expected value
    % (max excursion of vertical channel). If so, remove both + and -
    % peaks since it might be a blink.
    if peak_max > abs_peak_max || abs(peak_min) > abs_peak_max
        [pks, locs] = findpeaks(sd, fs, 'MinPeakHeight', abs_peak_max);
        
        if length(pks) >= 2
            % Distance between consecutive peaks
            pks_dist = diff(locs);
            
            % Double clicks
            % These are done with a double blink. We need to check first if
            % there are 2 consecutive peaks higher than the abs_peak_max
            % threshold within a fs / 2 distance.
            if min(pks_dist) < fs / 2
                disp 'double click'
                double_click = true;
                % Discard peaks.
                peak_min = 0;
                peak_max = 0;
            end
        end
    end
    
    % Add positive and negative peaks to counteract their effect.
    peaks(i) = peak_min + peak_max;
    if abs(peaks(i)) < noise_lim(i)
        peaks(i) = 0;
    end
    
%     if i == 2
%         if abs(peaks(i)) > 0 && abs(peaks(1)) > 0 && sign(peaks(i)) == sign(peaks(1))
%             peaks(1) = 0;
%         end
%     end
end

% Remove first n samples, used to compute derivative only
channel_data = channel_data(n_der+1:end, :);
end