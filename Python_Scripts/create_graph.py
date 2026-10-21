import os 
# import cv2
import numpy as np
import traceback
from PIL import Image 
# from imgraph import GraphPresets


def create_patches(img, patchsize):
     if img.ndim == 3:
        img = img[..., 0]

     img = img.astype(np.float32) / 255.0
     #define the image shape
     H,W = img.shape
     patches = []
     for i in range(0, H, patchsize):
         for j in range (0, W, patchsize):
             subimage = img[i:i+patchsize, j:j+patchsize]
             # 2. Only add patches that are the full size (prevents partial edge patches) 
             patches.append(subimage) 
     patches = np.array(patches)
     return patches
# load img 
# img = Image.open("dataset/5G_only/5G_only_SNR+0p1_SIRNA_example_217.png").convert("L")
# img = img.resize((256,256))
# img = np.array(img)
# # img.show()     
# patches, patches_len = create_patches(img, 8)
# print(patches)
# print(patches_len)