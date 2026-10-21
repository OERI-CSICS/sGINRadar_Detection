# Radar Interference Detection in 5G Networks

This repository contains the simulation, dataset-generation, and machine-learning pipeline used for radar-interference detection in 5G uplink signals. MATLAB is used to generate the IQ data and corresponding spectrograms, while the Python pipeline performs spectrogram-based graph construction and radar-interference classification.

## Repository Structure

```text
Radar-Interference-Detection/
├── MATLAB_Scripts/
│   ├── IQ_datageneration.m
│   ├── generate_dataset.m
│   ├── radar.m
│   └── SNRperformance.m
│
├── Python_Scripts/
│   ├── Radar_detection.ipynb
│   ├── dataset_pyg.py
│   ├── create_graph.py
│   ├── graph_utils.py
│   ├── model.py
│   ├── train.py
│   ├── embedding.py
│   └── CNN_model.py
│
├── Datasets/                 # generated locally; not committed
│   ├── IQ_Data/
│   └── Spectrogram_Dataset/
│       ├── 5G_only/
│       └── Radar_plus_5G/
│
├── saved_models/
├── results/
├── requirements.txt
└── README.md
```

## Dataset Generation

The MATLAB scripts generate the simulated 5G uplink and radar signals, produce the IQ samples, and convert the signals into spectrogram images.

- `MATLAB_Scripts/IQ_datageneration.m` generates the IQ data.
- `MATLAB_Scripts/radar.m` contains the radar-signal generation components.
- `MATLAB_Scripts/generate_dataset.m` generates the spectrogram dataset used for detection.
- `MATLAB_Scripts/SNRperformance.m` supports signal/SNR-related evaluation.

The generated IQ and spectrogram datasets are **not included in this repository** because they are generated artifacts and can be reproduced using the provided MATLAB scripts. By default, generated IQ samples should be stored in `Datasets/IQ_Data/`, while the resulting spectrogram images should be stored in `Datasets/Spectrogram_Dataset/`. The spectrogram dataset contains two classes:

- `5G_only/` — 5G uplink signals without radar interference.
- `Radar_plus_5G/` — 5G uplink signals containing radar interference.

## Installation

Create a Python environment and install the required dependencies:

```bash
python3 -m venv gnn_env
source gnn_env/bin/activate
pip install -r requirements.txt
```

The Python implementation uses packages including PyTorch, PyTorch Geometric, NumPy, pandas, scikit-learn, Pillow, and Matplotlib.

## Running Radar Detection

First run the MATLAB scripts to generate the IQ data and spectrogram images. The expected local dataset structure is `Datasets/IQ_Data/` for IQ samples and `Datasets/Spectrogram_Dataset/` for the two spectrogram classes. These generated directories should remain local and are excluded from version control.

After generating the spectrogram dataset, run:

```text
Python_Scripts/Radar_detection.ipynb
```

The notebook is the main entry point for the radar-interference detection experiments. It uses the supporting Python modules for dataset loading, patch-feature extraction, graph construction, model definition, training, and evaluation.

The overall workflow is:

```text
MATLAB signal generation
        ↓
      IQ data
        ↓
Spectrogram generation
        ↓
5G_only / Radar_plus_5G
        ↓
Radar_detection.ipynb
        ↓
Graph construction and classification
        ↓
Detection results
```

## Models

The repository contains the proposed spectrogram-based Graph Isomorphism Network (sGIN) together with baseline models used for comparison, including GCN, ResNet18, Logistic Regression, and SVM experiments.

## Results

Evaluation outputs, including detection metrics and probability-of-detection analyses, can be stored in the `results/` directory. Trained model checkpoints are stored separately in `saved_models/`.
