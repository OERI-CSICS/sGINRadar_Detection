import torch
obj = torch.load("gin_radar_detector.pt", map_location="cpu")
print(type(obj))

if isinstance(obj, dict):
    print("DICT KEYS:")
    for k in obj.keys():
        print(" ", k)
