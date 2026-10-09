from datetime import datetime

from sqlalchemy import (
    Column,
    Integer,
    String,
    Float,
    DateTime,
    ForeignKey,
    Text,
)

from database.database import Base


# =========================================================
# CITIZEN
# =========================================================

class User(Base):
    __tablename__ = "users"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    name = Column(
        String,
        nullable=False
    )

    age = Column(
        Integer,
        nullable=False
    )

    username = Column(
        String,
        unique=True,
        nullable=False,
        index=True
    )

    password = Column(
        String,
        nullable=False
    )

    latitude = Column(
        Float,
        nullable=False
    )

    longitude = Column(
        Float,
        nullable=False
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )


# =========================================================
# ADMIN
# =========================================================

class Admin(Base):
    __tablename__ = "admins"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    username = Column(
        String,
        unique=True,
        nullable=False,
        index=True
    )

    password = Column(
        String,
        nullable=False
    )

    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )


# =========================================================
# COMPLAINT
# =========================================================

class Complaint(Base):
    __tablename__ = "complaints"

    id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    # Owner of this complaint
    user_id = Column(
        Integer,
        ForeignKey("users.id"),
        nullable=False,
        index=True
    )

    # Complaint information
    category = Column(
        String,
        nullable=False
    )

    description = Column(
        Text,
        nullable=False
    )

    # Complaint location
    latitude = Column(
        Float,
        nullable=False
    )

    longitude = Column(
        Float,
        nullable=False
    )

    # Uploaded evidence
    image_path = Column(
        String,
        nullable=True
    )

    # YOLO result
    ai_detected_class = Column(
        String,
        nullable=True
    )

    ai_confidence = Column(
        Float,
        nullable=True
    )

    # Random Forest input
    severity_score = Column(
        Integer,
        nullable=False,
        default=5
    )

    public_impact = Column(
        Integer,
        nullable=False,
        default=5
    )

    safety_risk = Column(
        Integer,
        nullable=False,
        default=5
    )

    repeat_reports = Column(
        Integer,
        nullable=False,
        default=0
    )

    near_sensitive_area = Column(
        String,
        nullable=False,
        default="no"
    )

    # Random Forest output
    priority = Column(
        String,
        nullable=False,
        default="MEDIUM"
    )

    # AI/routing result
    department = Column(
        String,
        nullable=True
    )

    # Complaint workflow
    status = Column(
        String,
        nullable=False,
        default="Submitted"
    )

    # Admin processing
    assigned_admin = Column(
        String,
        nullable=True
    )

    admin_action = Column(
        Text,
        nullable=True
    )

    latest_update = Column(
        Text,
        nullable=True
    )

    # Timestamps
    created_at = Column(
        DateTime,
        default=datetime.utcnow
    )

    updated_at = Column(
        DateTime,
        default=datetime.utcnow,
        onupdate=datetime.utcnow
    )