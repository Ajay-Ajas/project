import os
import shutil
from pathlib import Path

# ==========================================
# CivicMind AI Dataset Merger
# ==========================================

BASE_DIR = Path(__file__).parent

DATASETS = {
    "road": {
        "class_map": {0: 0},  # damage -> road_damage
    },

    "garbage": {
        # We will skip invalid class "Images"
        # garbage becomes class 1
        "class_map": {
            0: None,
            1: 1
        }
    },

    "water": {
        # Merge all water conditions into one class
        "class_map": {
            0: 2,
            1: 2,
            2: 2,
            3: 2,
            4: 2
        }
    },

    "fallentree": {
        "class_map": {0: 3}
    },

    "streetlight": {
        "class_map": {0: 4}
    }
}

OUTPUT = BASE_DIR / "merged_dataset"

SPLITS = ["train", "valid", "test"]

for split in SPLITS:
    (OUTPUT / split / "images").mkdir(parents=True, exist_ok=True)
    (OUTPUT / split / "labels").mkdir(parents=True, exist_ok=True)

image_counter = 0

for dataset_name, info in DATASETS.items():

    dataset_path = BASE_DIR / "datasets" / dataset_name

    print(f"\nProcessing {dataset_name}")

    for split in SPLITS:

        img_dir = dataset_path / split / "images"
        lbl_dir = dataset_path / split / "labels"

        if not img_dir.exists():
            continue

        for img in img_dir.iterdir():

            if img.suffix.lower() not in [".jpg", ".jpeg", ".png"]:
                continue

            label = lbl_dir / (img.stem + ".txt")

            if not label.exists():
                continue

            new_name = f"{dataset_name}_{image_counter}{img.suffix}"

            shutil.copy(
                img,
                OUTPUT / split / "images" / new_name
            )

            new_label = OUTPUT / split / "labels" / (
                Path(new_name).stem + ".txt"
            )

            new_lines = []

            with open(label, "r") as f:

                for line in f:

                    parts = line.strip().split()

                    if len(parts) == 0:
                        continue

                    old_class = int(parts[0])

                    if old_class not in info["class_map"]:
                        continue

                    new_class = info["class_map"][old_class]

                    if new_class is None:
                        continue

                    parts[0] = str(new_class)

                    new_lines.append(" ".join(parts))

            if len(new_lines) == 0:
                continue

            with open(new_label, "w") as f:
                f.write("\n".join(new_lines))

            image_counter += 1

print("\n================================")
print("Dataset Merge Completed")
print("================================")
print("Merged Images:", image_counter)
