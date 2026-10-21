import numpy as np
import torch
from torch_geometric.data import Data
from sklearn.neighbors import kneighbors_graph
from torch_geometric.utils import from_scipy_sparse_matrix, to_undirected

def image_to_graph(img, y, patch_size):
    if img.ndim == 3:
        img = img[..., 0]

    img = img.astype(np.float32) / 255.0
    H, W = img.shape

    H = (H // patch_size) * patch_size
    W = (W // patch_size) * patch_size
    img = img[:H, :W]

    H2 = H // patch_size
    W2 = W // patch_size

    features = []

    for pr in range(H2):
        for pc in range(W2):
            r0 = pr * patch_size
            c0 = pc * patch_size
            patch = img[r0:r0 + patch_size, c0:c0 + patch_size]

            # patch center
            center_r = r0 + patch_size / 2.0
            center_c = c0 + patch_size / 2.0

            freq_norm = center_r / (H - 1) if H > 1 else 0.0
            time_norm = center_c / (W - 1) if W > 1 else 0.0

            features.append([
                patch.mean(),
                patch.std(),
                patch.max(),
                patch.min(),
                # np.sum(np.square(patch)),
                # time_norm,
                # freq_norm
            ])

    X = torch.tensor(features, dtype=torch.float)

    def node_id(pr, pc):
        return pr * W2 + pc

    X_np = X.numpy()

    

    adj = kneighbors_graph(
            X_np,
            n_neighbors=32,
            mode='distance',
            include_self=False
        )
    
    # Make graph undirected
    adj = adj.maximum(adj.T)
    edge_index = torch.tensor(
    np.array(adj.nonzero()),
    dtype=torch.long
    )
    edge_index = to_undirected(edge_index)
    # edge_index, _ = from_scipy_sparse_matrix(adj)
    return Data(
        x=X,
        edge_index=edge_index,
        y=torch.tensor([y], dtype=torch.long)
    )

    