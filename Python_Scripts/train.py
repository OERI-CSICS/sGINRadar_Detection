import torch
from sklearn.metrics import accuracy_score, f1_score, confusion_matrix
from model_copy import GINClassifier

def run_epoch(model, loader, optimizer=None, device="cpu"):
    train_mode = optimizer is not None
    model.train() if train_mode else model.eval()

    all_y = []
    all_pred = []
    total_loss = 0.0
    criterion = torch.nn.CrossEntropyLoss()

    for batch in loader:
        batch = batch.to(device)
        logits = model(batch)
        y = batch.y.view(-1)

        loss = criterion(logits, y)
        if train_mode:
            optimizer.zero_grad()
            loss.backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
            optimizer.step()

        total_loss += float(loss.item()) * y.size(0)
        pred = logits.argmax(dim=1).detach().cpu().numpy()
        all_pred.extend(pred.tolist())
        all_y.extend(y.detach().cpu().numpy().tolist())

    avg_loss = total_loss / len(loader.dataset)
    acc = accuracy_score(all_y, all_pred)
    f1  = f1_score(all_y, all_pred)
    cm  = confusion_matrix(all_y, all_pred)
    return avg_loss, acc, f1, cm


device = "cuda" if torch.cuda.is_available() else "cpu"
model = GINClassifier().to(device)

optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(optimizer, mode="max", factor=0.5, patience=3)

best_val_f1 = -1
best_state = None

for epoch in range(1, 31):
    tr_loss, tr_acc, tr_f1, _ = run_epoch(model, train_loader, optimizer=optimizer, device=device)
    va_loss, va_acc, va_f1, va_cm = run_epoch(model, val_loader, optimizer=None, device=device)

    scheduler.step(va_f1)

    print(f"Epoch {epoch:02d} train loss {tr_loss:.4f} acc {tr_acc:.3f} f1 {tr_f1:.3f}  val loss {va_loss:.4f} acc {va_acc:.3f} f1 {va_f1:.3f}")
    print("Val confusion matrix")
    print(va_cm)

    if va_f1 > best_val_f1:
        best_val_f1 = va_f1
        best_state = {k: v.cpu().clone() for k, v in model.state_dict().items()}
