import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database.db import init_db, get_db
from app.api.models import Base
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
import os

SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)

@pytest.fixture(autouse=True)
def setup_database():
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
    if os.path.exists("./test.db"):
        os.remove("./test.db")

def test_register_user():
    response = client.post("/api/register", json={
        "email": "test@example.com",
        "name": "Test User",
        "password": "password"
    })
    assert response.status_code == 200
    assert response.json()["email"] == "test@example.com"

def test_login():
    client.post("/api/register", json={
        "email": "test@example.com",
        "name": "Test User",
        "password": "password"
    })
    response = client.post("/api/login", data={
        "username": "test@example.com",
        "password": "password"
    })
    assert response.status_code == 200
    assert "access_token" in response.json()

def test_upload_file():
    client.post("/api/register", json={
        "email": "test@example.com",
        "name": "Test User",
        "password": "password"
    })
    login_response = client.post("/api/login", data={
        "username": "test@example.com",
        "password": "password"
    })
    token = login_response.json()["access_token"]
    
    with open("test.txt", "w") as f:
        f.write("This is a test.")
    with open("test.txt", "rb") as f:
        response = client.post(
            "/api/upload",
            files={"file": ("test.txt", f, "text/plain")},
            headers={"Authorization": f"Bearer {token}"}
        )
    os.remove("test.txt")
    
    assert response.status_code == 200
    assert "originalText" in response.json()
    assert "improvedText" in response.json()
    assert "suggestions" in response.json()

def test_get_file_types():
    response = client.get("/api/config/file-types")
    assert response.status_code == 200
    assert isinstance(response.json(), list)
    assert len(response.json()) > 0