import pandas as pd
import joblib

from sklearn.model_selection import train_test_split
from sklearn.compose import ColumnTransformer
from sklearn.preprocessing import OneHotEncoder
from sklearn.pipeline import Pipeline
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix
)

# ==========================================
# CivicMind AI - Priority ML Training
# ==========================================

# Load dataset
df = pd.read_csv("priority_dataset.csv")

print("Dataset loaded successfully")
print("Total samples:", len(df))
print()

# Features and target
X = df.drop("priority", axis=1)
y = df["priority"]

# Categorical and numerical features
categorical_features = ["category"]

numerical_features = [
    "severity_score",
    "public_impact",
    "safety_risk",
    "repeat_reports",
    "near_sensitive_area"
]

# Preprocessing
preprocessor = ColumnTransformer(
    transformers=[
        (
            "category",
            OneHotEncoder(handle_unknown="ignore"),
            categorical_features
        )
    ],
    remainder="passthrough"
)

# Random Forest model
model = RandomForestClassifier(
    n_estimators=200,
    random_state=42,
    max_depth=10,
    class_weight="balanced"
)

# Complete pipeline
pipeline = Pipeline(
    steps=[
        ("preprocessor", preprocessor),
        ("classifier", model)
    ]
)

# Train/test split
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.20,
    random_state=42,
    stratify=y
)

print("Training samples:", len(X_train))
print("Testing samples:", len(X_test))
print()

# Train
print("Training Random Forest...")
pipeline.fit(X_train, y_train)

print("Training completed!")
print()

# Prediction
y_pred = pipeline.predict(X_test)

# Accuracy
accuracy = accuracy_score(y_test, y_pred)

print("==========================================")
print("CIVICMIND AI PRIORITY MODEL RESULTS")
print("==========================================")
print(f"Accuracy: {accuracy:.4f}")
print()
print("Classification Report:")
print(classification_report(y_test, y_pred))

print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

# Save model
joblib.dump(
    pipeline,
    "priority_model.joblib"
)

print()
print("Model saved as: priority_model.joblib")