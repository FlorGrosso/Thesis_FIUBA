%**************************************************************************
%                            TESIS DE GRADO
%                               EEG v1.0
%                   Instituto de Ingeniería Biomédica
%           Facultad de Ingeniería, Universidad de Buenos Aires
%
%                           Florencia Grosso
%                           Tutor: Sergio Lew
%
%  Code description:
%  This code reads the data sent by the IC ADS1299 through an Arduino NANO.
%  It saves it in a txt file which will be passed then to a plotter
%  function.
%
%  INPUT args:
%   - peaks: matrix of detected voltage peaks per stimuli for each channel. 
%   - cal_stimuli: M x 2 matrix with calibration stimuli coordinates.
%   - noise_per_stim: fill or "noise" points to add per stimuli (>0).
%**************************************************************************

function [eeg_data_rand, stimuli_pos_rand] = noise_adder(peaks, cal_stimuli, noise_per_stim)
% Invert peaks for the rotated screen. This means that:
% screen's x maps to -CH2 (vertical)
% screen's y maps to CH1 (horizontal)
% peaks = [-peaks(:, 2), peaks(:, 1)];

% Get max values for X and Y axes (1/2 full excursion). 
ch1_lim = max(abs(peaks(:,1)));
ch2_lim =  max(abs(peaks(:,2)));

% ADD RANDOM NOISE
% First, we need to compute the voltage span from the center of a control
% to its borders (in x & y). Cap it to 90% to avoid overflowing the button.
max_noise_ch1 = 0.9 * ch1_lim / 4;
max_noise_ch2 = 0.9 * ch2_lim / 2;

% Inflated data (stimuli coordinates and corresponding eog peaks).
eog_data_inflated = [];
stimuli_pos_inflated = [];

for i=1:1:length(peaks)
    eog_data_inflated = [eog_data_inflated; peaks(i,:)];
    stimuli_pos_inflated = [stimuli_pos_inflated; cal_stimuli(i,:)];
    
    % Adding noise_per_stim points per real sample
    for j=1:1:noise_per_stim
        % The resulting point can fall anywhere inside the button as:
        % button_center - max_noise_xy <(x,y)< button_center + max_noise_xy        
        ch1 = peaks(i,1) + 2*max_noise_ch1*rand(1) - max_noise_ch1;
        ch2 = peaks(i,2) + 2*max_noise_ch2*rand(1) - max_noise_ch2;
        
        % Accumulate inflated points
        eog_data_inflated = [eog_data_inflated; [ch1 ch2]];
        % The position of the stimuli keeps the original coordinates.
        stimuli_pos_inflated = [stimuli_pos_inflated; cal_stimuli(i,:)];
    end
end

%% SHUFFLE DATA

% Now shuffle the complete dataset randomly.
idxs = randperm(length(eog_data_inflated));
eeg_data_rand = eog_data_inflated(idxs,:);
stimuli_pos_rand = stimuli_pos_inflated(idxs,:);

end





