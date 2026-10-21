from torch.utils.data import Dataset
from PIL import Image
import numpy as np
import graph_utils
import torch

# import graph_utilscopy
import importlib
importlib.reload(graph_utils)
from graph_utils import image_to_graph
class SpectrogramGraphDataset(Dataset):

    def __init__(self, dataframe, resize=(256,256),  patch_size = 16):
        self.df = dataframe.reset_index(drop=True)
        self.resize = resize
        self.patch_size = patch_size
    

    def __len__(self):
        return len(self.df)

    # def __getitem__(self, idx):
    #     row = self.df.iloc[idx]

    #     img = Image.open(row["path"]).convert("L")
    #     img = img.resize(self.resize)
    #     img = np.array(img)

    #     data = image_to_graph(img,
    #                           y=int(row["y"]), 
    #                           patch_size=self.patch_size)

    #     return data 

    def __getitem__(self, idx):
        row = self.df.iloc[idx]

        img = Image.open(row["path"]).convert("L")
        img = img.resize(self.resize)
        img = np.array(img)

        data = image_to_graph(
            img,
            y=int(row["y"]),
            patch_size=self.patch_size
        )

        # Attach one SIR value to this graph
        data.sir_db = torch.tensor(
            [float(row["SIR_dB"])],
            dtype=torch.float
        )

        return data
