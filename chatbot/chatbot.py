import joblib
import spacy
from pathlib import Path

# ============================================================
# CivicMind AI - NLP Chatbot
# ============================================================

BASE_DIR = Path(__file__).resolve().parent
MODEL_FILE = BASE_DIR / "intent_model.joblib"

# Load spaCy
nlp = spacy.load("en_core_web_sm")

# Load trained intent classifier
model = joblib.load(MODEL_FILE)


# ============================================================
# CHATBOT RESPONSES
# ============================================================

RESPONSES = {

    "general_app":
        "CivicMind AI is an AI-assisted civic governance platform "
        "that helps citizens report, track and manage public issues.",

    "report_complaint":
        "To report a civic issue, open Raise Complaint, select "
        "the appropriate category, enter the details, attach "
        "evidence if available, add the location and submit it.",

    "complaint_status":
        "You can track your complaint from My Complaints. "
        "The status timeline shows its current progress.",

    "road_damage":
        "For potholes or damaged roads, select Road Damage "
        "when raising your complaint and attach an image if possible.",

    "garbage":
        "For garbage or waste problems, select Garbage and "
        "provide the issue location and supporting evidence.",

    "streetlight":
        "For a broken street light, select Street Light and "
        "provide the location and an image if available.",

    "water_pollution":
        "For visible water pollution or contamination, select "
        "Water Pollution and provide supporting evidence.",

    "fallen_tree":
        "For a fallen tree, select Fallen Tree and provide "
        "the location and an image if available.",

    "location_help":
        "Location helps associate a civic complaint with the "
        "place where the issue occurred and assists administrative routing.",

    "image_help":
        "Images provide supporting evidence and can also be "
        "analyzed by the CivicMind AI vision module.",

    "ai_detection":
        "CivicMind AI uses YOLO11 for computer-vision assistance. "
        "The current civic detector is designed for road damage, "
        "garbage, water pollution, fallen trees and street lights.",

    "priority":
        "CivicMind AI uses complaint information to assist with "
        "priority classification. The prototype priority model "
        "classifies complaints as LOW, MEDIUM or HIGH.",

    "department":
        "CivicMind suggests a responsible department based on "
        "the complaint category. Final assignment remains under "
        "authorized administrative review.",

    "public_feed":
        "The Public Feed allows citizens to view community-visible "
        "civic complaints and their progress.",

    "upvote":
        "Community upvotes allow citizens to support a publicly "
        "visible civic issue.",

    "status_meaning":
        "Complaint statuses represent the workflow: Submitted, "
        "Pending Review, In Progress and Resolved.",

    "privacy":
        "CivicMind supports public and private complaint visibility. "
        "The visibility option is selected when submitting a complaint.",

    "chatbot_help":
        "I can help you understand CivicMind AI, report civic issues, "
        "track complaints, understand AI detection, priority, routing "
        "and other application features."
}


# ============================================================
# ENTITY EXTRACTION
# ============================================================

def extract_entities(text):
    """
    Use spaCy to extract named entities.
    """

    doc = nlp(text)

    entities = []

    for ent in doc.ents:
        entities.append({
            "text": ent.text,
            "label": ent.label_
        })

    return entities


# ============================================================
# INTENT CLASSIFICATION
# ============================================================

def classify_intent(text):
    """
    Predict the user's intent using the trained ML model.
    """

    prediction = model.predict([text])[0]

    probabilities = model.predict_proba([text])[0]

    classes = model.classes_

    best_index = probabilities.argmax()

    confidence = probabilities[best_index]

    return (
        prediction,
        confidence,
        classes,
        probabilities
    )


# ============================================================
# PROCESS CHAT MESSAGE
# ============================================================

def process_message(text):

    intent, confidence, classes, probabilities = \
        classify_intent(text)

    entities = extract_entities(text)

    response = RESPONSES.get(
        intent,
        "I can help with CivicMind AI, civic complaints, "
        "status tracking, AI detection, priority and routing."
    )

    return {
        "intent": intent,
        "confidence": float(confidence),
        "entities": entities,
        "response": response
    }


# ============================================================
# TERMINAL TEST MODE
# ============================================================

def main():

    print("==============================================")
    print("          CIVICMIND AI CHATBOT")
    print("==============================================")
    print("NLP Engine : spaCy")
    print("Intent ML  : TF-IDF + Logistic Regression")
    print("Type 'exit' to stop")
    print("==============================================\n")

    while True:

        user_input = input("Citizen: ").strip()

        if not user_input:
            continue

        if user_input.lower() == "exit":
            print("\nCivicMind AI: Goodbye!")
            break

        result = process_message(user_input)

        print()
        print("Detected Intent :", result["intent"])

        print(
            "Confidence      : "
            f"{result['confidence']:.2%}"
        )

        if result["entities"]:
            print(
                "Entities        :",
                result["entities"]
            )

        print()
        print(
            "CivicMind AI    :",
            result["response"]
        )
        print()


# ============================================================
# RUN TERMINAL CHATBOT ONLY WHEN FILE IS EXECUTED DIRECTLY
# ============================================================

if __name__ == "__main__":
    main()