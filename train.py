from ultralytics import YOLO

def main():
    # Load YOLO11 Nano model
    model = YOLO("yolo11n.pt")

    # Train
    model.train(
        data="merged_dataset/data.yml",
        epochs=100,
        imgsz=640,
        batch=8,          # Better for 16 GB RAM
        workers=2,        # Windows friendly
        patience=20,
        project="training",
        name="civicmind_ai",
        pretrained=True,
        device="cpu"      # Change to 0 only if you have an NVIDIA GPU
    )

if __name__ == "__main__":
    main()