from database.database import SessionLocal
from database.models import Admin


admins = [
    ("ajay", "aqua"),
    ("jeswin", "jeswin"),
    ("abin", "abin"),
    ("sanjay", "sanjay"),
    ("hod", "hod"),
]


db = SessionLocal()

try:
    for username, password in admins:

        existing_admin = (
            db.query(Admin)
            .filter(Admin.username == username)
            .first()
        )

        if existing_admin:
            print(f"Admin already exists: {username}")
        else:
            new_admin = Admin(
                username=username,
                password=password
            )

            db.add(new_admin)
            print(f"Admin created: {username}")

    db.commit()

    print()
    print("ALL ADMIN ACCOUNTS READY")

finally:
    db.close()