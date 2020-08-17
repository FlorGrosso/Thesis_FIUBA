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
%  This function calculates the prediction for a perceptron with a single
%  hidden layer.
%
%  INPUT args:
%  - input: matrix of inputs to the nn
%  - Weight matrices:
%       w1: input to hidden layer
%       w2: hidden layer to output
%  - Bias matrices:
%       b1: input to hidden layer
%       b2: hidden layer to output
% 
%  OUTPUT:
%  - output: matrix of predictions for the given input
%**************************************************************************

function v_2 = get_nn_prediction(input, w1, w2, bias1, bias2)
% Let the caller provide these data, to avoid reading the file on each call
% w1 = csvread(strcat('..\..\Pytorch\output\w1_', train_data_id, '.txt'));
% w2 = csvread(strcat('..\..\Pytorch\output\w2_', train_data_id, '.txt'));
% 
% bias1 = csvread(strcat('..\..\Pytorch\output\bias1_', train_data_id, '.txt'));
% bias2 = csvread(strcat('..\..\Pytorch\output\bias2_', train_data_id, '.txt'));

% Apply the input pattern to the first layer.
v0 = input;

% Propagate the input signal thrwough the network.
% m = 1
h_1 = v0 * w1'  + bias1';
v_1 = 1./(1 + exp(-h_1)); % poslin=h_relu

% m = 2
h_2 = v_1 * w2'  + bias2';
v_2 = 1./(1 + exp(-h_2)); % poslin=h_relu
end