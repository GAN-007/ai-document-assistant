from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from typing import List
from app.core.auth import create_access_token, get_current_user, verify_password, get_password_hash
from app.core.document_processor import process_document
from app.database.db import get_db
from app.schemas.document import DocumentResponse, Suggestion
from app.schemas.user import UserCreate, UserResponse
from app.api.models import User, Document
from app.settings.config import SUPPORTED_FILE_TYPES, MODEL_INFO
from datetime import timedelta
import os

router = APIRouter()

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/login")

@router.post("/register", response_model=UserResponse)
async def register(user: UserCreate, db: Session = Depends(get_db)):
    # Check if user exists
    db_user = db.query(User).filter(User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    # Create new user
    hashed_password = get_password_hash(user.password)
    db_user = User(
        email=user.email,
        name=user.name,
        hashed_password=hashed_password,
        role="user"
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.post("/login")
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(data={"sub": user.email}, expires_delta=access_token_expires)
    return {"access_token": access_token, "token_type": "bearer", "user": UserResponse.from_orm(user)}

@router.post("/validate-token", response_model=UserResponse)
async def validate_token(current_user: User = Depends(get_current_user)):
    return current_user

@router.post("/upload", response_model=DocumentResponse)
async def upload_file(file: UploadFile = File(...), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    if not any(file.content_type == ft["mime_type"] for ft in SUPPORTED_FILE_TYPES):
        raise HTTPException(status_code=400, detail="Unsupported file type")
    if file.size > 10 * 1024 * 1024:  # 10MB limit
        raise HTTPException(status_code=400, detail="File too large")
    
    content = await file.read()
    original_text, improved_text, suggestions = await process_document(file.filename, content, file.content_type)
    
    # Save document
    db_document = Document(
        user_id=current_user.id,
        filename=file.filename,
        content=improved_text
    )
    db.add(db_document)
    db.commit()
    
    return DocumentResponse(
        originalText=original_text,
        improvedText=improved_text,
        suggestions=suggestions
    )

@router.post("/save")
async def save_document(document: DocumentResponse, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    db_document = db.query(Document).filter(Document.user_id == current_user.id, Document.filename == document.filename).first()
    if not db_document:
        db_document = Document(
            user_id=current_user.id,
            filename=document.filename,
            content=document.improvedText
        )
        db.add(db_document)
    else:
        db_document.content = document.improvedText
    db.commit()
    return {"message": "Document saved successfully"}

@router.get("/config/file-types")
async def get_file_types():
    return SUPPORTED_FILE_TYPES

@router.get("/model-info")
async def get_model_info():
    return MODEL_INFO