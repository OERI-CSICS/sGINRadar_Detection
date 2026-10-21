import torch
import torch.nn.functional as F
from torch_geometric.nn import GINConv, global_mean_pool, global_max_pool
from torch.nn import Sequential, Linear, ReLU, BatchNorm1d, GELU

class GINClassifier(torch.nn.Module):
    def __init__(self, in_dim=4, hidden=64, num_layers=4, num_classes=2, dropout=0.2):
        super().__init__()
        self.convs = torch.nn.ModuleList()
        self.bns   = torch.nn.ModuleList()
        self.dropout = dropout

        for i in range(num_layers):
            mlp = Sequential(
                Linear(in_dim if i == 0 else hidden, hidden),
                GELU(),
                Linear(hidden, hidden)
            )
            self.convs.append(GINConv(mlp))
            self.bns.append(BatchNorm1d(hidden))

        self.head = torch.nn.Sequential(
            Linear(hidden, hidden),
            ReLU(),
            torch.nn.Dropout(dropout),
            Linear(hidden, num_classes)
        )

    def forward(self, data):
        x, edge_index, batch = data.x, data.edge_index, data.batch
        for conv, bn in zip(self.convs, self.bns):
            x = conv(x, edge_index)
            x = bn(x)
            x = F.relu(x)
            x = F.dropout(x, p=self.dropout, training=self.training)

        g = global_mean_pool(x, batch)
        out = self.head(g)
        return out
