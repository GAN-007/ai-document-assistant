from pydantic import BaseModel
from typing import List

class Suggestion(BaseModel):
    id: int
    start: int
    end: int
    original_text: str
    improved_text: str
    reason: str
    status: str

    class Config:
        orm_mode = True

class DocumentResponse(BaseModel):
    originalText: str
    improvedText: str
    suggestions: List[Suggestion]
    filename: str = "unnamed_document"

    class Config:
        orm_mode = True