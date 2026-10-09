import joblib
import pandas as pd

# Load trained model
model = joblib.load("priority_model.joblib")

print("CivicMind AI Priority Model")
print("===========================")

# Example complaint
complaint = pd.DataFrame([
    {
        "category": "road_damage",
        "severity_score": 8,
        "public_impact": 8,
        "safety_risk": 9,
        "repeat_reports": 6,
        "near_sensitive_area": 1
    }
])

# Predict
prediction = model.predict(complaint)[0]

# Probability
probabilities = model.predict_proba(complaint)[0]
classes = model.classes_

print()
print("Complaint:")
print("Category: Road Damage")
print("Severity: 8/10")
print("Public Impact: 8/10")
print("Safety Risk: 9/10")
print("Repeat Reports: 6")
print("Near Sensitive Area: Yes")

print()
print("Predicted Priority:", prediction)

print()
print("Prediction Probabilities:")

for class_name, probability in zip(classes, probabilities):
    print(f"{class_name}: {probability:.2%}")