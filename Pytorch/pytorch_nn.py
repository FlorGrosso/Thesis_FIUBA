"""
                               TESIS DE GRADO
                                  EEG v1.0
                      Instituto de Ingeniería Biomédica
              Facultad de Ingeniería, Universidad de Buenos Aires
   
                              Florencia Grosso
                         Tutor: Dr. Ing. Sergio Lew
 
 Code description:
 This script executes the backwards propagation algorithm in Pytorch for a
 multilayer perceptron with:
     - 2 input units
     - 8 hidden units
     - 2 output units
     
 input args:
     - data_id: identifier to load input files, also used to name output files
     
 input_data:
     - input patterns and desired output, which are loaded from csv files
     located at ./input_data
     
 output_data:
     - weight and bias matrices (weights, bias), saved under ./output_data

"""

import numpy as np
import pandas as pd
import sys
import torch

# Check for input args
# Data id to be used as an identifier for input/output files
if len(sys.argv) == 2:
    data_id = sys.argv[1]
else:
    # If no id is specified, use a default value.
    data_id = 'Florencia_Grosso_09_08_2020_11_05_05' #'02_05_2019_22_49_08'
    

# Filenames to save training output to
cwd = 'C:/Users/Flor/Dropbox/TESIS/Code/Pytorch/'
suffix = data_id + '.txt'
w1_file_name = cwd + 'output/w1_' + suffix
w2_file_name = cwd + 'output/w2_' + suffix
bias1_file_name = cwd + 'output/bias1_' + suffix
bias2_file_name = cwd + 'output/bias2_' + suffix
pred_file = cwd + 'output/pred_' + suffix

# Neural network params
# Input dimension
D_in = 2
# Hidden dimension
H = 8
# Output dimension
D_out = 2

# Learning rate
c = 1e-3
# Number of training cycles to perform
epochs = 10000

# Torch specifics
dtype = torch.float
#device = torch.device("cpu")
device = torch.device("cuda:0") # run on GPU
    
# Load training data (input patterns and desired output)
x0=torch.tensor(pd.read_csv(cwd + 'input_data/input_' + data_id + '_filled.txt', header=None).values,device=device,dtype=dtype)
y0=torch.tensor(pd.read_csv(cwd + 'input_data/output_' + data_id + '_filled.txt', header=None).values,device=device,dtype=dtype)

# NOTE: this is assuming that data is already shuffled randomly from origin.
train_length = int(np.round(len(x0) * 0.7));
print(train_length);

x=x0[:train_length - 1, :]
y=y0[:train_length - 1, :]

# Use the nn package to define a secuential model model for a 2 layer perceptron.
model = torch.nn.Sequential(
          torch.nn.Linear(D_in, H),
          torch.nn.Sigmoid(),
          torch.nn.Linear(H, D_out),
          torch.nn.Sigmoid(),
        )
# Use MSE a loss function.
loss_fn = torch.nn.MSELoss(reduction='sum')

model.cuda()

# Use the optim package to define an Optimizer that will update the weights of
# the model for us. Here we will use Adam; the optim package contains many other
# optimization algoriths. The first argument to the Adam constructor tells the
# optimizer which Tensors it should update.
optimizer = torch.optim.Adam(model.parameters(), lr=c)

# Backwards propagation algorithm
for t in range(epochs):    
  # Forward pass: compute predicted y by passing x to the model.
  y_pred = model(x)
  
  # Compute and print loss.
  loss = loss_fn(y_pred, y)
  print(t, loss.item())
  
  # Before the backward pass, use the optimizer object to zero all of the
  # gradients for the Tensors it will update (which are the learnable weights
  # of the model)
  optimizer.zero_grad()

  # Backward pass: compute gradient of the loss with respect to model parameters
  loss.backward()

  # Calling the step function on an Optimizer makes an update to its parameters
  optimizer.step()

# Now save the prediction, weights and bias data to files
with torch.no_grad():
  np.savetxt(pred_file, y_pred.to("cpu").numpy(), delimiter=",")
  np.savetxt(w1_file_name, model[0].weight.to("cpu").numpy(), delimiter=",")
  np.savetxt(bias1_file_name, model[0].bias.to("cpu").numpy(), delimiter=",")
  np.savetxt(w2_file_name, model[2].weight.to("cpu").numpy(), delimiter=",")
  np.savetxt(bias2_file_name, model[2].bias.to("cpu").numpy(), delimiter=",")
  
print("FINISHED")