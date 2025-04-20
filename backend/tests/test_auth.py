import pytest
from app.core.auth import verify_password, get_password_hash, create_access_token
from jose import jwt
from datetime import timedelta

def test_password_hashing():
    password = "testpassword"
    hashed = get_password_hash(password)
    assert verify_password(password, hashed)
    assert not verify_password("wrongpassword", hashed)

def test_create_access_token():
    data = {"sub": "test@example.com"}
    token = create_access_token(data, expires_delta=timedelta(minutes=15))
    decoded = jwt.decode(token, "your-secret-key-here", algorithms=["HS256"])
    assert decoded["sub"] == "test@example.com"
    assert "exp" in decoded