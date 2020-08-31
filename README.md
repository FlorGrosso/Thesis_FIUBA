# Thesis FIUBA

**"Eye tracking based on EOG signal processing"**

Instituto de Ingeniería Biomédica

Universidad de Buenos Aires

2020

---------------------------------------------

This repository contains the software for a BCI designed to control a virtual d-pad using EOG signals as input. The code is divided in 3 blocks: Arduino, Matlab and Pytorch.

## Arduino
Software to control an IC ADS1299 through an Arduino NANO. It handles the startup sequence (configuration, setup) of the device and triggers the data conversion. The processing loop reads data continuously, processes it and sends it to a computer through SPI.

## Matlab
This is where the main block of the BCI is implemented. The `main.m` script reads data transmitted by the Arduino and executes the complete test which consists of:

1. Calibration stage
- Presents the calibration interface.
- Records eog data from vertical & horizontal channel and stores them into a file.
- Processes the data to extract the features to train the NN (input & desired output).

2. Training of the NN
- Calls the Pytorch script that trains the network. 

3. Live test
- Presents the testing interface, which reads and processes data continuously, online.

## Pytorch
This directory contains a Python script (`python_nn.py`) that executes a backwards propagation algorithm in Pytorch for a multilayer perceptron with:
- 2 input units
- 8 hidden units
- 2 output units

It uses the data placed in `input_data` for training and stores the output data (weight and bias matrices) into `output_data`.
