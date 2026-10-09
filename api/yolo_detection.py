from ultralytics import YOLO

MODEL_PATH = "../yolo/best.pt"

model = YOLO(MODEL_PATH)


def detect_image(image_path):
    results = model.predict(
        source=image_path,
        conf=0.25,
        imgsz=640
    )

    detections = []

    for result in results:
        if result.boxes is None:
            continue

        for box in result.boxes:
            class_id = int(box.cls[0])
            confidence = float(box.conf[0])

            detections.append({
                "class": model.names[class_id],
                "confidence": round(confidence, 3)
            })

    return detections
if __name__ == "__main__":
    image_path = "../merged_dataset/valid/images"
    results = detect_image(image_path)
    print("DETECTIONS:")
    print(results)