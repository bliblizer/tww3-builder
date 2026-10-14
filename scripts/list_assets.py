# scripts/list_assets.py
"""Liste tous les fichiers image des dossiers assets/ (nom sans extension)."""
from pathlib import Path
import csv

ASSETS = Path("assets")
OUT = Path("exports/assets_filenames.csv")

FOLDERS = [
    "unit_cards",
    "portraits_units",
    "race_images",
    "unit_category_icons",
    "ability_icons",
    "mount_icons",
    "ui_skins",
    "stats_icons",
    "artworks",
]

EXTS = {".png", ".webp", ".jpg", ".jpeg"}

rows = []
for folder in FOLDERS:
    p = ASSETS / folder
    if not p.exists():
        print(f"⚠ dossier absent : {p}")
        continue
    for f in p.rglob("*"):
        if f.is_file() and f.suffix.lower() in EXTS:
            rows.append({
                "folder": folder,
                "name":   f.stem,                    # ← nom sans extension
                "ext":    f.suffix.lower(),
                "subpath": f.relative_to(ASSETS).as_posix(),
            })

OUT.parent.mkdir(exist_ok=True)
with OUT.open("w", newline="", encoding="utf-8") as fh:
    w = csv.DictWriter(fh, fieldnames=["folder", "name", "ext", "subpath"])
    w.writeheader()
    w.writerows(rows)

print(f"{len(rows)} fichiers listés → {OUT}")