import pandas as pd
import joblib

from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    accuracy_score,
    classification_report,
    confusion_matrix
)

# ==========================================
# CivicMind AI - NLP Intent Classifier
# ==========================================

DATASET = "chatbot_dataset.csv"
MODEL_FILE = "intent_model.joblib"

# Load dataset
df = pd.read_csv(DATASET)

print("==========================================")
print("CIVICMIND AI NLP INTENT TRAINING")
print("==========================================")
print("Dataset loaded successfully")
print("Total examples:", len(df))
print("Total intents:", df["intent"].nunique())
print()

# Input and target
X = df["text"]
y = df["intent"]

# Train/test split
X_train, X_test, y_train, y_test = train_test_split(
    X,
    y,
    test_size=0.20,
    random_state=42,
    stratify=y
)

print("Training examples:", len(X_train))
print("Testing examples:", len(X_test))
print()

# TF-IDF + Logistic Regression
model = Pipeline([
    (
        "tfidf",
        TfidfVectorizer(
            lowercase=True,
            ngram_range=(1, 2),
            sublinear_tf=True
        )
    ),
    (
        "classifier",
        LogisticRegression(
            max_iter=2000,
            class_weight="balanced"
        )
    )
])

# Train
print("Training NLP intent classifier...")
model.fit(X_train, y_train)

print("Training completed!")
print()

# Test
y_pred = model.predict(X_test)

accuracy = accuracy_score(y_test, y_pred)

print("==========================================")
print("CIVICMIND AI NLP RESULTS")
print("==========================================")
print(f"Accuracy: {accuracy:.4f}")
print()

print("Classification Report:")
print(classification_report(y_test, y_pred, zero_division=0))

print("Confusion Matrix:")
print(confusion_matrix(y_test, y_pred))

# Save
joblib.dump(model, MODEL_FILE)

print()
print("Model saved as:", MODEL_FILE)
print("==========================================")