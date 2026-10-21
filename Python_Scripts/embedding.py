## Here is the code for the feature node embedding using CNN embedding
import torch
import torch.nn as nn
import torch.nn.functional as F

    

class CNNPatchEmbedding(nn.Module):
    def __init__(self, in_channels=1, embed_dim=4):
        super().__init__()

        self.cnn = nn.Sequential(
            nn.Conv2d(in_channels, 16, kernel_size=3, padding=1),
            nn.ReLU(),

            nn.Conv2d(16, 32, kernel_size=3, padding=1),
            nn.ReLU(),

            nn.AdaptiveAvgPool2d((1,1))
        )

        self.fc = nn.Linear(32, embed_dim)

    def forward(self, patches):
        """
        patches:
        [num_patches, channels, patch_h, patch_w]
        """

        x = self.cnn(patches)

        x = x.view(x.size(0), -1)

        embeddings = self.fc(x)

        return embeddings
    

# create Autoencoder embedding as well

class Autoencoder(nn.Module):
    def __init__(self, in_channels, embed_dim=64):
        super().__init__()

        self.enc = nn.Sequential(
            nn.Conv2d(in_channels, 32, kernel_size=5, padding=1),
            nn.ReLU(),

            nn.Conv2d(32, 16, kernel_size=3, padding=1),
            nn.ReLU(),

            nn.AdaptiveAvgPool2d((1,1))
        )

        self.fc = nn.Linear(16, embed_dim)

    def forward(self, patches):

        x = self.enc(patches)

        x = x.view(x.size(0), -1)

        encoded = self.fc(x)

        return encoded
