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
%  Returns an MxN matrix with splitted channel data, where M is the number
%  of samples per channel and N the number of active channels.  
%
%  This also undoes arduino amplification and converts samples to uV.
%
%  INPUT args:
%   - eeg_data: raw eeg/eog data as an (N * M) colum vector.
%   - active_channel: number of active/on eeg channels (eog = 2).
%   - arduino_gain: initial signal amplification done by the ADS1299.
%**************************************************************************
function channel_data = split_channels(eeg_data, active_channels, arduino_gain)

for i=1:active_channels
    amplified_eeg_data(:,i) = eeg_data(i:active_channels:end, 1);
    
    % Undo amplification and convert to uV
    channel_data(:,i) = amplified_eeg_data(:,i) * 1000 / arduino_gain;
end
end
