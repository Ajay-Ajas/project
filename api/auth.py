from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from database.database import get_db
from database.models import User, Admin


router = APIRouter(
    prefix="/auth",
    tags=["Authentication"]
)


# -----------------------------
# REQUEST MODELS
# -----------------------------

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


# -----------------------------
# CITIZEN REGISTRATION
# -----------------------------

@router.post("/register")
def register_user(
    request: UserRegisterRequest,
    db: Session = Depends(get_db)
):

    existing_user = (
        db.query(User)
        .filter(User.username == request.username)
        .first()
    )

    existing_admin = (
        db.query(Admin)
        .filter(Admin.username == request.username)
        .first()
    )

    if existing_user or existing_admin:
        raise HTTPException(
            status_code=400,
            detail="Username already exists"
        )

    if request.age < 1:
        raise HTTPException(
            status_code=400,
            detail="Invalid age"
        )

    new_user = User(
        name=request.name,
        age=request.age,
        username=request.username,
        password=request.password,
        latitude=request.latitude,
        longitude=request.longitude
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    return {
        "success": True,
        "message": "Citizen account created successfully",
        "user": {
            "id": new_user.id,
            "name": new_user.name,
            "username": new_user.username,
            "latitude": new_user.latitude,
            "longitude": new_user.longitude
        }
    }


# -----------------------------
# LOGIN
# -----------------------------

@router.post("/login")
def login(
    request: LoginRequest,
    db: Session = Depends(get_db)
):

    # Check admin first
    admin = (
        db.query(Admin)
        .filter(Admin.username == request.username)
        .first()
    )

    if admin:
        if admin.password != request.password:
            raise HTTPException(
                status_code=401,
                detail="Invalid username or password"
            )

        return {
            "success": True,
            "role": "admin",
            "message": "Admin login successful",
            "username": admin.username
        }

    # Check citizen
    user = (
        db.query(User)
        .filter(User.username == request.username)
        .first()
    )

    if user:
        if user.password != request.password:
            raise HTTPException(
                status_code=401,
                detail="Invalid username or password"
            )

        return {
            "success": True,
            "role": "citizen",
            "message": "Citizen login successful",
            "user": {
                "id": user.id,
                "name": user.name,
                "username": user.username,
                "latitude": user.latitude,
                "longitude": user.longitude
            }
        }

    raise HTTPException(
        status_code=401,
        detail="Invalid username or password"
    )