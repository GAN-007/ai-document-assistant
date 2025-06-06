from pydantic import BaseModel
from typing import List

class Suggestion(BaseModel):
    text: str
    type: str

    class Config:
        from_attributes = True

class DocumentResponse(BaseModel):
    originalText: str
    improvedText: str
    suggestions: List[Suggestion]
    filename: str

    class Config:
        from_attributes = True
