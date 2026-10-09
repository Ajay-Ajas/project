from pathlib import Path

import joblib
import pandas as pd


# ---------------------------------------------------------
# PATHS
# ---------------------------------------------------------

BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_PATH = (
    BASE_DIR
    / "priority_ml"
    / "priority_model.joblib"
)


# ---------------------------------------------------------
# LOAD RANDOM FOREST MODEL
# ---------------------------------------------------------

priority_model = joblib.load(MODEL_PATH)

print("Priority model loaded successfully")


# ---------------------------------------------------------
# CATEGORY NORMALIZATION
# ---------------------------------------------------------

VALID_CATEGORIES = {
    "road_damage",
    "garbage",
    "water_pollution",
    "fallen_tree",
    "street_lights",
    "water_supply",
    "electricity",
    "sanitation",
    "environment",
    "other",
}


def normalize_category(category):
    """
    Keep category as a string because the trained
    Random Forest pipeline uses categorical encoding.
    """

    if category is None:
        return "other"

    category = str(category).strip().lower()

    if category in VALID_CATEGORIES:
        return category

    return "other"


# ---------------------------------------------------------
# YES / NO NORMALIZATION
# ---------------------------------------------------------

def normalize_sensitive_area(value):
    """
    Convert yes/no input into the numeric representation
    expected by the trained model.

    yes -> 1
    no  -> 0
    """

    if isinstance(value, bool):
        return 1 if value else 0

    if value is None:
        return 0

    value = str(value).strip().lower()

    if value in {
        "yes",
        "true",
        "1",
        "y",
        "near",
        "nearby",
    }:
        return 1

    return 0


# ---------------------------------------------------------
# PRIORITY PREDICTION
# ---------------------------------------------------------

def predict_priority(
    category,
    severity_score,
    public_impact,
    safety_risk,
    repeat_reports,
    near_sensitive_area
):

    category = normalize_category(category)

    near_sensitive_area = normalize_sensitive_area(
        near_sensitive_area
    )

    data = pd.DataFrame(
        [
            {
                "category": category,
                "severity_score": float(severity_score),
                "public_impact": float(public_impact),
                "safety_risk": float(safety_risk),
                "repeat_reports": float(repeat_reports),
                "near_sensitive_area": near_sensitive_area,
            }
        ]
    )

    prediction = priority_model.predict(data)

    return str(prediction[0])


# ---------------------------------------------------------
# DEPARTMENT ROUTING
# ---------------------------------------------------------

def get_department(category):

    category = normalize_category(category)

    department_map = {

        "road_damage":
            "Public Works & Transport Department",

        "garbage":
            "Sanitation & Waste Department",

        "water_pollution":
            "Water Board",

        "water_supply":
            "Water Board",

        "street_lights":
            "Electricity Board",

        "electricity":
            "Electricity Board",

        "fallen_tree":
            "Environment Department",

        "environment":
            "Environment Department",

        "sanitation":
            "Sanitation & Waste Department",

        "other":
            "Administrative Review",
    }

    return department_map.get(
        category,
        "Administrative Review"
    )


# ---------------------------------------------------------
# COMPLETE COMPLAINT TRIAGE
# ---------------------------------------------------------

def triage_complaint(
    complaint,
    category,
    severity_score,
    public_impact,
    safety_risk,
    repeat_reports,
    near_sensitive_area
):

    priority = predict_priority(
        category=category,
        severity_score=severity_score,
        public_impact=public_impact,
        safety_risk=safety_risk,
        repeat_reports=repeat_reports,
        near_sensitive_area=near_sensitive_area
    )

    department = get_department(category)

    return {
        "priority": priority,
        "suggested_department": department,
        "category": normalize_category(category),
        "near_sensitive_area":
            normalize_sensitive_area(
                near_sensitive_area
            )
    }