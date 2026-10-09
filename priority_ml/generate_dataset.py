import random
import pandas as pd

random.seed(42)

categories = [
    "road_damage",
    "garbage",
    "water_pollution",
    "fallen_tree",
    "street_lights",
]

rows = []

for _ in range(3000):
    category = random.choice(categories)

    severity_score = random.randint(1, 10)
    public_impact = random.randint(1, 10)
    safety_risk = random.randint(1, 10)
    repeat_reports = random.randint(0, 10)
    near_sensitive_area = random.randint(0, 1)

    score = (
        severity_score * 0.30
        + public_impact * 0.25
        + safety_risk * 0.30
        + min(repeat_reports, 5) * 0.15
        + near_sensitive_area * 1.0
    )

    if score >= 7:
        priority = "HIGH"
    elif score >= 4:
        priority = "MEDIUM"
    else:
        priority = "LOW"

    rows.append(
        {
            "category": category,
            "severity_score": severity_score,
            "public_impact": public_impact,
            "safety_risk": safety_risk,
            "repeat_reports": repeat_reports,
            "near_sensitive_area": near_sensitive_area,
            "priority": priority,
        }
    )

df = pd.DataFrame(rows)
df.to_csv("priority_dataset.csv", index=False)

print(df.head())
print()
print("Dataset size:", len(df))
print()
print(df["priority"].value_counts())