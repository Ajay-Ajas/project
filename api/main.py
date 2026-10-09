import os
import sys
import shutil
import tempfile
from pathlib import Path
PROJECT_ROOT = Path(__file__).resolve().parent.parent

if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))
from datetime import datetime
from chatbot.chatbot import process_message

from fastapi import (
    FastAPI,
    UploadFile,
    File,
    HTTPException,
    Depends,
    Form,
)

from fastapi.middleware.cors import CORSMiddleware

from pydantic import BaseModel

from ultralytics import YOLO

from sqlalchemy.orm import Session

# =========================================================
# PROJECT PATH
# =========================================================

BASE_DIR = Path(__file__).resolve().parent.parent

if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))


# =========================================================
# PROJECT IMPORTS
# =========================================================

from triage.triage import triage_complaint

from database.database import get_db

from database.models import (
    User,
    Admin,
    Complaint,
)


# =========================================================
# FASTAPI
# =========================================================

app = FastAPI(
    title="CivicMind AI API",
    description="AI-powered civic complaint management backend",
    version="1.0.0",
)


# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# =========================================================
# YOLO MODEL
# =========================================================

MODEL_PATH = BASE_DIR / "yolo" / "best.pt"

model = YOLO(str(MODEL_PATH))


# =========================================================
# UPLOAD DIRECTORY
# =========================================================

UPLOAD_DIR = BASE_DIR / "uploads" / "complaints"

UPLOAD_DIR.mkdir(
    parents=True,
    exist_ok=True,
)


# =========================================================
# REQUEST MODELS
# =========================================================

class ComplaintRequest(BaseModel):
    complaint: str
    category: str
    severity_score: int
    public_impact: int
    safety_risk: int
    repeat_reports: int
    near_sensitive_area: str


class UserRegisterRequest(BaseModel):
    name: str
    age: int
    username: str
    password: str
    latitude: float
    longitude: float


class LoginRequest(BaseModel):
    username: str
    password: str

class AdminComplaintUpdateRequest(BaseModel):
    admin_username: str
    status: str
    assigned_admin: str | None = None
    department: str | None = None
    admin_action: str | None = None
    latest_update: str | None = None

class ChatRequest(BaseModel):
    message: str
# =========================================================
# CATEGORY NORMALIZATION
# =========================================================

def normalize_category(category: str) -> str:

    value = category.strip().lower()

    mapping = {
        "road damage": "road_damage",
        "road_damage": "road_damage",

        "garbage": "garbage",

        "water pollution": "water_pollution",
        "water_pollution": "water_pollution",

        "fallen tree": "fallen_tree",
        "fallen_tree": "fallen_tree",

        "street light": "street_lights",
        "street lights": "street_lights",
        "street_light": "street_lights",
        "street_lights": "street_lights",
    }

    return mapping.get(
        value,
        value.replace(" ", "_")
    )


# =========================================================
# CATEGORY DISPLAY NAME
# =========================================================

def display_category(category: str) -> str:

    mapping = {
        "road_damage": "Road Damage",
        "garbage": "Garbage",
        "water_pollution": "Water Pollution",
        "fallen_tree": "Fallen Tree",
        "street_lights": "Street Light",
    }

    return mapping.get(
        category,
        category.replace("_", " ").title()
    )


# =========================================================
# AI CLASS DISPLAY NAME
# =========================================================

def display_ai_class(value: str) -> str:

    mapping = {
        "road_damage": "Road Damage",
        "garbage": "Garbage",
        "water_pollution": "Water Pollution",
        "fallen_tree": "Fallen Tree",
        "street_lights": "Street Light",
        "street_light": "Street Light",
    }

    return mapping.get(
        value,
        value.replace("_", " ").title()
    )


# =========================================================
# TRIAGE RESULT EXTRACTION
# =========================================================

def get_triage_value(
    result,
    possible_keys,
    default=None
):

    if isinstance(result, dict):

        for key in possible_keys:

            if key in result:

                return result[key]

    return default


# =========================================================
# YOLO IMAGE ANALYSIS
# =========================================================

def analyze_image(
    image_path: str
):

    results = model.predict(
        source=image_path,
        conf=0.25,
        imgsz=640,
        verbose=False,
    )

    detections = []

    for result in results:

        if result.boxes is None:
            continue

        for box in result.boxes:

            class_id = int(
                box.cls[0]
            )

            confidence = float(
                box.conf[0]
            )

            coordinates = (
                box.xyxy[0].tolist()
            )

            detections.append(
                {
                    "class": model.names[
                        class_id
                    ],

                    "confidence": round(
                        confidence,
                        3
                    ),

                    "bounding_box": {
                        "x1": round(
                            coordinates[0],
                            2
                        ),

                        "y1": round(
                            coordinates[1],
                            2
                        ),

                        "x2": round(
                            coordinates[2],
                            2
                        ),

                        "y2": round(
                            coordinates[3],
                            2
                        ),
                    },
                }
            )

    return detections


# =========================================================
# HOME
# =========================================================

@app.get("/")
def home():

    return {
        "application": "CivicMind AI",
        "status": "running",
        "message":
            "AI-powered civic governance backend is active",
    }


# =========================================================
# HEALTH
# =========================================================

@app.get("/health")
def health():

    return {
        "status": "healthy",
        "yolo_model": "loaded",
        "database": "connected",
    }


# =========================================================
# REGISTER
# =========================================================

@app.post("/auth/register")
def register_user(
    request: UserRegisterRequest,
    db: Session = Depends(get_db),
):

    existing_user = (
        db.query(User)
        .filter(
            User.username ==
            request.username
        )
        .first()
    )

    existing_admin = (
        db.query(Admin)
        .filter(
            Admin.username ==
            request.username
        )
        .first()
    )

    if existing_user or existing_admin:

        raise HTTPException(
            status_code=400,
            detail="Username already exists",
        )

    if request.age < 1:

        raise HTTPException(
            status_code=400,
            detail="Invalid age",
        )

    if not request.name.strip():

        raise HTTPException(
            status_code=400,
            detail="Name is required",
        )

    if not request.username.strip():

        raise HTTPException(
            status_code=400,
            detail="Username is required",
        )

    if not request.password.strip():

        raise HTTPException(
            status_code=400,
            detail="Password is required",
        )

    new_user = User(
        name=request.name,
        age=request.age,
        username=request.username,
        password=request.password,
        latitude=request.latitude,
        longitude=request.longitude,
    )

    db.add(new_user)

    db.commit()

    db.refresh(new_user)

    return {
        "success": True,

        "message":
            "Citizen account created successfully",

        "user": {
            "id": new_user.id,
            "name": new_user.name,
            "age": new_user.age,
            "username": new_user.username,
            "latitude": new_user.latitude,
            "longitude": new_user.longitude,
        },
    }


# =========================================================
# LOGIN
# =========================================================

@app.post("/auth/login")
def login(
    request: LoginRequest,
    db: Session = Depends(get_db),
):

    admin = (
        db.query(Admin)
        .filter(
            Admin.username ==
            request.username
        )
        .first()
    )

    if admin:

        if admin.password != request.password:

            raise HTTPException(
                status_code=401,
                detail=
                    "Invalid username or password",
            )

        return {
            "success": True,
            "role": "admin",
            "message":
                "Admin login successful",
            "username": admin.username,
        }

    user = (
        db.query(User)
        .filter(
            User.username ==
            request.username
        )
        .first()
    )

    if user:

        if user.password != request.password:

            raise HTTPException(
                status_code=401,
                detail=
                    "Invalid username or password",
            )

        return {
            "success": True,
            "role": "citizen",
            "message":
                "Citizen login successful",

            "user": {
                "id": user.id,
                "name": user.name,
                "age": user.age,
                "username": user.username,
                "latitude": user.latitude,
                "longitude": user.longitude,
            },
        }

    raise HTTPException(
        status_code=401,
        detail=
            "Invalid username or password",
    )


# =========================================================
# OLD TRIAGE ENDPOINT
# KEEPING THIS WORKING
# =========================================================

@app.post("/complaints/triage")
def complaint_triage(
    request: ComplaintRequest
):

    result = triage_complaint(

        complaint=request.complaint,

        category=request.category,

        severity_score=
            request.severity_score,

        public_impact=
            request.public_impact,

        safety_risk=
            request.safety_risk,

        repeat_reports=
            request.repeat_reports,

        near_sensitive_area=
            request.near_sensitive_area,
    )

    return {
        "success": True,
        "triage": result,
    }


# =========================================================
# YOLO DETECTION ENDPOINT
# =========================================================

@app.post("/ai/detect")
async def detect_civic_issue(
    file: UploadFile = File(...)
):

    allowed_types = {
        "image/jpeg",
        "image/jpg",
        "image/png",
        "image/webp",
    }

    if file.content_type not in allowed_types:

        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid file type. "
                "Please upload JPG, JPEG, PNG or WEBP image."
            ),
        )

    temp_path = None

    try:

        file_extension = Path(
            file.filename or "image.jpg"
        ).suffix

        with tempfile.NamedTemporaryFile(
            delete=False,
            suffix=file_extension,
        ) as temp_file:

            temp_path = temp_file.name

            shutil.copyfileobj(
                file.file,
                temp_file,
            )

        detections = analyze_image(
            temp_path
        )

        return {
            "success": True,

            "filename":
                file.filename,

            "detection_count":
                len(detections),

            "detections":
                detections,
        }

    except Exception as e:

        raise HTTPException(
            status_code=500,
            detail=
                f"YOLO detection failed: {str(e)}",
        )

    finally:

        if (
            temp_path
            and os.path.exists(temp_path)
        ):

            os.remove(temp_path)


# =========================================================
# CREATE COMPLETE COMPLAINT
# =========================================================

@app.post("/complaints/create")
async def create_complaint(

    user_id: int = Form(...),

    category: str = Form(...),

    description: str = Form(...),

    latitude: float = Form(...),

    longitude: float = Form(...),

    severity_score: int = Form(5),

    public_impact: int = Form(5),

    safety_risk: int = Form(5),

    repeat_reports: int = Form(0),

    near_sensitive_area: str = Form("no"),

    file: UploadFile | None = File(None),

    db: Session = Depends(get_db),
):

    # =====================================================
    # 1. CHECK USER
    # =====================================================

    user = (
        db.query(User)
        .filter(
            User.id == user_id
        )
        .first()
    )

    if not user:

        raise HTTPException(
            status_code=404,
            detail="Citizen account not found",
        )

    # =====================================================
    # 2. VALIDATE DESCRIPTION
    # =====================================================

    if not description.strip():

        raise HTTPException(
            status_code=400,
            detail="Complaint description is required",
        )

    # =====================================================
    # 3. NORMALIZE CATEGORY
    # =====================================================

    normalized_category = normalize_category(category)

    # =====================================================
    # 4. SAVE IMAGE
    # =====================================================

    saved_image_path = None

    if file is not None:

        allowed_types = {
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/webp",
        }

        if file.content_type not in allowed_types:

            raise HTTPException(
                status_code=400,
                detail=(
                    "Invalid image type. "
                    "Use JPG, JPEG, PNG or WEBP."
                ),
            )

        original_name = (
            file.filename
            or "complaint_image.jpg"
        )

        safe_name = (
            original_name
            .replace("/", "_")
            .replace("\\", "_")
            .replace(" ", "_")
        )

        timestamp = (
            datetime.now()
            .strftime("%Y%m%d_%H%M%S_%f")
        )

        final_name = (
            f"user_{user_id}_"
            f"{timestamp}_"
            f"{safe_name}"
        )

        final_path = (
            UPLOAD_DIR / final_name
        )

        with open(
            final_path,
            "wb"
        ) as buffer:

            shutil.copyfileobj(
                file.file,
                buffer,
            )

        saved_image_path = str(
            final_path.relative_to(
                BASE_DIR
            )
        )

    # =====================================================
    # 5. RUN YOLO
    # =====================================================

    ai_detected_class = None
    ai_confidence = None

    if saved_image_path:

        absolute_image_path = (
            BASE_DIR /
            saved_image_path
        )

        try:

            detections = analyze_image(
                str(absolute_image_path)
            )

            if detections:

                best_detection = max(
                    detections,
                    key=lambda x:
                        x["confidence"]
                )

                ai_detected_class = (
                    best_detection["class"]
                )

                ai_confidence = (
                    best_detection["confidence"]
                )

        except Exception as e:

            print(
                "YOLO complaint analysis warning:",
                e,
            )

    # =====================================================
    # 6. RUN RANDOM FOREST + ROUTING
    # =====================================================

    triage_result = triage_complaint(

        complaint=description,

        category=normalized_category,

        severity_score=severity_score,

        public_impact=public_impact,

        safety_risk=safety_risk,

        repeat_reports=repeat_reports,

        near_sensitive_area=
            near_sensitive_area,
    )

    # =====================================================
    # 7. GET PRIORITY
    # =====================================================

    priority = get_triage_value(
        triage_result,
        [
            "priority",
            "predicted_priority",
            "prediction",
        ],
        "MEDIUM",
    )

    priority = str(
        priority
    ).upper()

    # =====================================================
    # 8. GET DEPARTMENT
    # =====================================================

    department = get_triage_value(
        triage_result,
        [
            "department",
            "suggested_department",
        ],
        None,
    )

    if department is not None:

        department = str(
            department
        )

    # =====================================================
    # 9. CREATE DATABASE RECORD
    # =====================================================

    new_complaint = Complaint(

        user_id=user.id,

        category=normalized_category,

        description=description,

        latitude=latitude,

        longitude=longitude,

        image_path=saved_image_path,

        ai_detected_class=
            ai_detected_class,

        ai_confidence=
            ai_confidence,

        severity_score=
            severity_score,

        public_impact=
            public_impact,

        safety_risk=
            safety_risk,

        repeat_reports=
            repeat_reports,

        near_sensitive_area=
            near_sensitive_area,

        priority=priority,

        department=department,

        status="Submitted",

        assigned_admin=None,

        admin_action=None,

        latest_update=(
            "Complaint submitted successfully "
            "and is awaiting review."
        ),
    )

    db.add(
        new_complaint
    )

    db.commit()

    db.refresh(
        new_complaint
    )

    # =====================================================
    # 10. RESPONSE
    # =====================================================

    return {

        "success": True,

        "message":
            "Complaint submitted successfully",

        "complaint": {

            "id":
                new_complaint.id,

            "user_id":
                user.id,

            "user_name":
                user.name,

            "username":
                user.username,

            "category":
                display_category(
                    normalized_category
                ),

            "description":
                new_complaint.description,

            "latitude":
                new_complaint.latitude,

            "longitude":
                new_complaint.longitude,

            "image_path":
                new_complaint.image_path,

            "ai_detected_class":
                (
                    display_ai_class(
                        ai_detected_class
                    )
                    if ai_detected_class
                    else None
                ),

            "ai_confidence":
                ai_confidence,

            "priority":
                new_complaint.priority,

            "department":
                new_complaint.department,

            "status":
                new_complaint.status,

            "latest_update":
                new_complaint.latest_update,

            "created_at":
                new_complaint.created_at,
        },
    }
@app.get("/complaints/user/{user_id}")
def get_user_complaints(
    user_id: int,
    db: Session = Depends(get_db)
):
    complaints = (
        db.query(Complaint)
        .filter(Complaint.user_id == user_id)
        .order_by(Complaint.created_at.desc())
        .all()
    )

    return {
        "success": True,
        "user_id": user_id,
        "complaints": [
            {
                "id": complaint.id,
                "user_id": complaint.user_id,
                "category": display_category(complaint.category),
                "description": complaint.description,
                "latitude": complaint.latitude,
                "longitude": complaint.longitude,
                "image_path": complaint.image_path,
                "ai_detected_class": complaint.ai_detected_class,
                "ai_confidence": complaint.ai_confidence,
                "priority": complaint.priority,
                "department": complaint.department,
                "status": complaint.status,
                "latest_update": complaint.latest_update,
                "created_at": complaint.created_at.isoformat()
                    if complaint.created_at else None,
                "updated_at": complaint.updated_at.isoformat()
                    if complaint.updated_at else None,
            }
            for complaint in complaints
        ]
    }
    # =========================================================
# PUBLIC COMMUNITY FEED
# =========================================================

@app.get("/complaints/feed")
def get_complaint_feed(
    db: Session = Depends(get_db),
):
    complaints = (
        db.query(Complaint)
        .order_by(Complaint.created_at.desc())
        .all()
    )

    return {
        "success": True,
        "count": len(complaints),
        "complaints": [
            {
                "id": complaint.id,
                "user_id": complaint.user_id,
                "category": complaint.category,
                "description": complaint.description,
                "latitude": complaint.latitude,
                "longitude": complaint.longitude,
                "ai_detected_class":
                    complaint.ai_detected_class,
                "ai_confidence":
                    complaint.ai_confidence,
                "priority": complaint.priority,
                "department": complaint.department,
                "status": complaint.status,
                "latest_update":
                    complaint.latest_update,
                "created_at":
                    complaint.created_at.isoformat()
                    if complaint.created_at
                    else None,
                "updated_at":
                    complaint.updated_at.isoformat()
                    if complaint.updated_at
                    else None,
            }
            for complaint in complaints
        ],
    }
# =========================================================
# AJAS AI CHATBOT
# =========================================================

@app.post("/ai/chat")
def ai_chat(request: ChatRequest):

    message = request.message.strip()

    if not message:
        raise HTTPException(
            status_code=400,
            detail="Message cannot be empty."
        )

    try:
        result = process_message(message)

        return {
            "success": True,
            "message": message,
            "intent": result["intent"],
            "confidence": float(result["confidence"]),
            "entities": result["entities"],
            "response": result["response"],
        }

    except Exception as e:
        print("Chatbot error:", e)

        raise HTTPException(
            status_code=500,
            detail="Ajas chatbot could not process the message."
        )
# =========================================================
# ADMIN - GET ALL COMPLAINTS
# =========================================================

@app.get("/admin/complaints")
def get_all_admin_complaints(
    admin_username: str,
    db: Session = Depends(get_db),
):
    # Check that the requester is an administrator
    admin = (
        db.query(Admin)
        .filter(
            Admin.username == admin_username
        )
        .first()
    )

    if not admin:
        raise HTTPException(
            status_code=403,
            detail="Administrator access required",
        )

    complaints = (
        db.query(Complaint)
        .order_by(
            Complaint.created_at.desc()
        )
        .all()
    )

    result = []

    for complaint in complaints:

        user = (
            db.query(User)
            .filter(
                User.id == complaint.user_id
            )
            .first()
        )

        result.append({
            "id": complaint.id,
            "user_id": complaint.user_id,
            "user_name": (
                user.name
                if user
                else "Unknown Citizen"
            ),
            "username": (
                user.username
                if user
                else None
            ),
            "category": display_category(
                complaint.category
            ),
            "description": complaint.description,
            "latitude": complaint.latitude,
            "longitude": complaint.longitude,
            "image_path": complaint.image_path,
            "ai_detected_class": (
                display_ai_class(
                    complaint.ai_detected_class
                )
                if complaint.ai_detected_class
                else None
            ),
            "ai_confidence": complaint.ai_confidence,
            "priority": complaint.priority,
            "department": complaint.department,
            "status": complaint.status,
            "assigned_admin": complaint.assigned_admin,
            "admin_action": complaint.admin_action,
            "latest_update": complaint.latest_update,
            "created_at": complaint.created_at,
            "updated_at": complaint.updated_at,
        })

    return {
        "success": True,
        "count": len(result),
        "complaints": result,
    }


# =========================================================
# ADMIN - GET SINGLE COMPLAINT
# =========================================================

@app.get("/admin/complaints/{complaint_id}")
def get_admin_complaint(
    complaint_id: int,
    admin_username: str,
    db: Session = Depends(get_db),
):
    # Check administrator
    admin = (
        db.query(Admin)
        .filter(
            Admin.username == admin_username
        )
        .first()
    )

    if not admin:
        raise HTTPException(
            status_code=403,
            detail="Administrator access required",
        )

    complaint = (
        db.query(Complaint)
        .filter(
            Complaint.id == complaint_id
        )
        .first()
    )

    if not complaint:
        raise HTTPException(
            status_code=404,
            detail="Complaint not found",
        )

    user = (
        db.query(User)
        .filter(
            User.id == complaint.user_id
        )
        .first()
    )

    return {
        "success": True,
        "complaint": {
            "id": complaint.id,
            "user_id": complaint.user_id,
            "user_name": (
                user.name
                if user
                else "Unknown Citizen"
            ),
            "username": (
                user.username
                if user
                else None
            ),
            "category": display_category(
                complaint.category
            ),
            "description": complaint.description,
            "latitude": complaint.latitude,
            "longitude": complaint.longitude,
            "image_path": complaint.image_path,
            "ai_detected_class": (
                display_ai_class(
                    complaint.ai_detected_class
                )
                if complaint.ai_detected_class
                else None
            ),
            "ai_confidence": complaint.ai_confidence,
            "priority": complaint.priority,
            "department": complaint.department,
            "status": complaint.status,
            "assigned_admin": complaint.assigned_admin,
            "admin_action": complaint.admin_action,
            "latest_update": complaint.latest_update,
            "created_at": complaint.created_at,
            "updated_at": complaint.updated_at,
        },
    }


# =========================================================
# ADMIN - UPDATE COMPLAINT
# =========================================================

@app.put("/admin/complaints/{complaint_id}")
def update_admin_complaint(
    complaint_id: int,
    request: AdminComplaintUpdateRequest,
    db: Session = Depends(get_db),
):
    # -----------------------------------------------------
    # CHECK ADMIN
    # -----------------------------------------------------

    admin = (
        db.query(Admin)
        .filter(
            Admin.username ==
            request.admin_username
        )
        .first()
    )

    if not admin:
        raise HTTPException(
            status_code=403,
            detail="Administrator access required",
        )

    # -----------------------------------------------------
    # FIND COMPLAINT
    # -----------------------------------------------------

    complaint = (
        db.query(Complaint)
        .filter(
            Complaint.id == complaint_id
        )
        .first()
    )

    if not complaint:
        raise HTTPException(
            status_code=404,
            detail="Complaint not found",
        )

    # -----------------------------------------------------
    # VALID STATUS
    # -----------------------------------------------------

    valid_statuses = {
        "Submitted",
        "Pending Review",
        "In Progress",
        "Resolved",
    }

    new_status = request.status.strip()

    # Normalize status
    status_lookup = {
        "submitted": "Submitted",
        "pending review": "Pending Review",
        "in progress": "In Progress",
        "resolved": "Resolved",
    }

    new_status = status_lookup.get(
        new_status.lower()
    )

    if new_status is None:
        raise HTTPException(
            status_code=400,
            detail=(
                "Invalid status. Use: "
                "Submitted, Pending Review, "
                "In Progress or Resolved."
            ),
        )

    # -----------------------------------------------------
    # STATUS TRANSITION
    # -----------------------------------------------------

    status_order = {
        "Submitted": 1,
        "Pending Review": 2,
        "In Progress": 3,
        "Resolved": 4,
    }

    current_status = complaint.status

    current_rank = status_order.get(
        current_status,
        1
    )

    new_rank = status_order[new_status]

    if new_rank < current_rank:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Complaint is already at "
                f"'{current_status}'. "
                f"Status cannot move backwards."
            ),
        )

    # -----------------------------------------------------
    # ASSIGN ADMIN
    # -----------------------------------------------------

    assigned_admin = (
        request.assigned_admin
        or complaint.assigned_admin
        or request.admin_username
    )

    # -----------------------------------------------------
    # UPDATE FIELDS
    # -----------------------------------------------------

    complaint.status = new_status

    complaint.assigned_admin = assigned_admin

    if request.department is not None:
        complaint.department = (
            request.department.strip()
            or complaint.department
        )

    if request.admin_action is not None:
        complaint.admin_action = (
            request.admin_action.strip()
        )

    # Automatically create a useful update
    if request.latest_update is not None:
        latest_update = (
            request.latest_update.strip()
        )

        if latest_update:
            complaint.latest_update = (
                latest_update
            )
    else:
        complaint.latest_update = (
            f"Complaint status updated to "
            f"{new_status} by administrator "
            f"{request.admin_username}."
        )

    complaint.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(complaint)

    # -----------------------------------------------------
    # RESPONSE
    # -----------------------------------------------------

    user = (
        db.query(User)
        .filter(
            User.id == complaint.user_id
        )
        .first()
    )

    return {
        "success": True,
        "message": (
            "Complaint updated successfully"
        ),
        "complaint": {
            "id": complaint.id,
            "user_id": complaint.user_id,
            "user_name": (
                user.name
                if user
                else "Unknown Citizen"
            ),
            "category": display_category(
                complaint.category
            ),
            "description": complaint.description,
            "priority": complaint.priority,
            "department": complaint.department,
            "status": complaint.status,
            "assigned_admin":
                complaint.assigned_admin,
            "admin_action":
                complaint.admin_action,
            "latest_update":
                complaint.latest_update,
            "updated_at":
                complaint.updated_at,
        },
    }