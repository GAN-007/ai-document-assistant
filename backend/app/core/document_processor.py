import logging
import re
from typing import Dict, List, Tuple, Optional
from dataclasses import dataclass
import PyPDF2
from docx import Document
import pandas as pd
from fastapi import UploadFile
import io
import json
from settings.config import config
from transformers import T5Tokenizer, T5ForConditionalGeneration
import difflib
import asyncio
import ollama

# Configure logging
logger = logging.getLogger(__name__)

class DocumentProcessingError(Exception):
    """Custom exception for document processing errors."""
    pass

@dataclass
class Suggestion:
    """Represents a text improvement suggestion."""
    id: int
    start: int
    end: int
    original_text: str
    improved_text: str
    reason: str
    status: str = "pending"

class AIModelError(Exception):
    """Custom exception for AI model processing errors."""
    pass

@dataclass
class TextImprovementResult:
    """Result of text improvement operation."""
    improved_text: str
    suggestions: List[Dict]

class OllamaModel:
    """Ollama-based AI model implementation."""
    
    def __init__(self, model_name: str):
        self.model_name = model_name
        try:
            # Verify model availability
            ollama.show(model_name)
            logger.info(f"Ollama model {model_name} initialized")
        except Exception as e:
            logger.error(f"Failed to initialize Ollama model {model_name}: {str(e)}")
            raise AIModelError(f"Failed to initialize Ollama model {model_name}: {str(e)}")

    async def improve_text(self, text: str, suggestions: bool = True) -> TextImprovementResult:
        """Improve text using Ollama model."""
        if not text.strip():
            logger.warning("Empty text provided for improvement")
            return TextImprovementResult(improved_text=text, suggestions=[])
        
        try:
            prompt = f"""
            Improve the following text for clarity, grammar, and style. {'Provide a list of suggestions with reasons if suggestions=True.' if suggestions else ''}
            Text: {text}
            Format the response as JSON with 'improved_text' and 'suggestions' fields.
            Suggestions should include 'id', 'start', 'end', 'original_text', 'improved_text', 'reason', and 'status'.
            """
            response = await asyncio.to_thread(ollama.chat, model=self.model_name, messages=[
                {'role': 'user', 'content': prompt}
            ])
            result = json.loads(response['message']['content'])
            return TextImprovementResult(
                improved_text=result.get('improved_text', text),
                suggestions=result.get('suggestions', []) if suggestions else []
            )
        except Exception as e:
            logger.error(f"Ollama {self.model_name} text improvement failed: {str(e)}")
            raise AIModelError(f"Ollama {self.model_name} text improvement failed: {str(e)}")

class T5Model:
    """T5-based AI model implementation for text improvement."""
    
    def __init__(self, model_name: str = "t5-small"):
        try:
            logger.info(f"Loading T5 model: {model_name}")
            self.tokenizer = T5Tokenizer.from_pretrained(model_name)
            self.model = T5ForConditionalGeneration.from_pretrained(model_name)
        except Exception as e:
            logger.error(f"Failed to initialize T5 model: {str(e)}")
            raise AIModelError(f"Failed to initialize T5 model: {str(e)}")

    async def improve_text(self, text: str, suggestions: bool = True) -> TextImprovementResult:
        """Improve text using T5 model and generate suggestions."""
        if not text.strip():
            logger.warning("Empty text provided for improvement")
            return TextImprovementResult(improved_text=text, suggestions=[])
        
        try:
            # Prepare input for T5
            input_text = f"paraphrase: {text}"
            inputs = self.tokenizer(input_text, return_tensors="pt", max_length=512, truncation=True)
            # Run model inference in a separate thread to avoid blocking
            outputs = await asyncio.to_thread(
                self.model.generate, **inputs, max_length=512, num_beams=4, early_stopping=True
            )
            improved_text = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
            
            # Generate suggestions by comparing original and improved text
            suggestions = []
            if suggestions:
                suggestions = self._generate_suggestions(text, improved_text)
            
            return TextImprovementResult(
                improved_text=improved_text,
                suggestions=[s.__dict__ for s in suggestions]
            )
        except Exception as e:
            logger.error(f"T5 text improvement failed: {str(e)}")
            raise AIModelError(f"T5 text improvement failed: {str(e)}")

    def _generate_suggestions(self, original_text: str, improved_text: str) -> List[Suggestion]:
        """Generate suggestions by comparing original and improved text."""
        suggestions = []
        matcher = difflib.SequenceMatcher(None, original_text, improved_text)
        suggestion_id = 1

        for tag, i1, i2, j1, j2 in matcher.get_opcodes():
            if tag in ('replace', 'delete', 'insert'):
                original_segment = original_text[i1:i2]
                improved_segment = improved_text[j1:j2] if tag != 'delete' else ''
                reason = self._get_suggestion_reason(original_segment, improved_segment, tag)
                
                if original_segment.strip() or improved_segment.strip():
                    suggestions.append(Suggestion(
                        id=suggestion_id,
                        start=i1,
                        end=i2,
                        original_text=original_segment,
                        improved_text=improved_segment,
                        reason=reason,
                        status="pending"
                    ))
                    suggestion_id += 1

        return suggestions

    def _get_suggestion_reason(self, original: str, improved: str, tag: str) -> str:
        """Determine the reason for a suggestion."""
        if tag == 'replace':
            if len(original) == len(improved):
                return "Corrected potential typo or improved word choice"
            return "Improved clarity or style"
        elif tag == 'delete':
            return "Removed redundant or unnecessary text"
        elif tag == 'insert':
            return "Added text for clarity or completeness"
        return "General improvement"

class AIDocumentModel:
    """Main AI model interface for document processing."""
    
    def __init__(self):
        """Initialize AI models with fallback mechanism."""
        self.models = []
        self.model_info = {
            "model_type": "multi-model",
            "supported_features": {
                "text_improvement": True,
                "ocr": False,
                "transcription": False
            }
        }

        # Initialize Ollama models
        for model_name in [config.ai.get('ollama_model_primary', 'llama3.1:latest'), 
                         config.ai.get('ollama_model_secondary', 'llama2:latest')]:
            try:
                model = OllamaModel(model_name=model_name)
                self.models.append(('ollama', model_name, model))
                logger.info(f"Initialized Ollama model: {model_name}")
            except AIModelError as e:
                logger.warning(f"Skipping Ollama model {model_name}: {str(e)}")

        # Initialize T5 as fallback
        try:
            t5_model = T5Model(model_name=config.ai.get('t5_model_name', 't5-small'))
            self.models.append(('t5', 't5-small', t5_model))
            logger.info("Initialized T5 model as fallback")
        except AIModelError as e:
            logger.error(f"Failed to initialize T5 model: {str(e)}")
            raise AIModelError("No models available: T5 initialization failed")

        if not self.models:
            raise AIModelError("No AI models could be initialized")

    async def improve_text(self, text: str, suggestions: bool = True) -> Dict:
        """Improve text using available models with fallback."""
        if not isinstance(text, str):
            logger.error("Invalid text input: must be a string")
            raise AIModelError("Text must be a string")
        
        for model_type, model_name, model in self.models:
            try:
                logger.info(f"Attempting text improvement with {model_type} ({model_name})")
                result = await model.improve_text(text, suggestions)
                self.model_info["active_model"] = f"{model_type}:{model_name}"
                return {
                    "improved_text": result.improved_text,
                    "suggestions": result.suggestions
                }
            except AIModelError as e:
                logger.warning(f"Model {model_type} ({model_name}) failed: {str(e)}")
                continue
            except Exception as e:
                logger.warning(f"Unexpected error with {model_type} ({model_name}): {str(e)}")
                continue
        
        logger.error("All models failed to process text")
        raise AIModelError("All AI models failed to process text")

    def get_model_info(self) -> Dict:
        """Return information about the current model configuration."""
        return self.model_info

async def process_document(file: UploadFile) -> Tuple[str, str, List[Suggestion]]:
    """Process an uploaded document and return original text, improved text, and suggestions."""
    try:
        content_type = file.content_type
        file_content = await file.read()
        
        # Extract text based on file type
        original_text = await extract_text(file_content, content_type, file.filename)
        
        # Initialize AI model
        ai_model = AIDocumentModel()
        
        # Improve text using available models
        result = await ai_model.improve_text(original_text, suggestions=True)
        improved_text = result["improved_text"]
        suggestions = [Suggestion(**s) for s in result["suggestions"]]
        
        return original_text, improved_text, suggestions
    except AIModelError as e:
        logger.error(f"AI processing error: {str(e)}")
        raise DocumentProcessingError(f"Failed to process document: {str(e)}")
    except Exception as e:
        logger.error(f"Document processing failed: {str(e)}")
        raise DocumentProcessingError(f"Failed to process document: {str(e)}")

async def extract_text(file_content: bytes, content_type: str, filename: str) -> str:
    """Extract text from a file based on its content type."""
    try:
        if content_type == "application/pdf":
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(file_content))
            text = ""
            for page in pdf_reader.pages:
                text += page.extract_text() or ""
            return text.strip()
        
        elif content_type == "application/vnd.openxmlformats-officedocument.wordprocessingml.document":
            doc = Document(io.BytesIO(file_content))
            text = "\n".join([para.text for para in doc.paragraphs])
            return text.strip()
        
        elif content_type in ["text/plain", "text/csv"]:
            text = file_content.decode("utf-8", errors="ignore")
            return text.strip()
        
        elif content_type in [
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        ]:
            df = pd.read_excel(io.BytesIO(file_content))
            return df.to_string()
        
        elif content_type == "application/sql":
            text = file_content.decode("utf-8", errors="ignore")
            return text.strip()
        
        elif content_type == "application/zip":
            # For simplicity, extract text files from zip
            import zipfile
            with zipfile.ZipFile(io.BytesIO(file_content), "r") as zip_ref:
                text = ""
                for file_name in zip_ref.namelist():
                    if file_name.endswith(".txt"):
                        with zip_ref.open(file_name) as f:
                            text += f.read().decode("utf-8", errors="ignore") + "\n"
            return text.strip()
        
        elif content_type == "application/x-rar":
            # Placeholder for RAR handling
            return ""
        
        elif content_type.startswith("image/"):
            # OCR not supported in this implementation
            raise DocumentProcessingError("Image OCR not supported by current models")
        
        elif content_type.startswith("audio/") or content_type.startswith("video/"):
            # Transcription not supported in this implementation
            raise DocumentProcessingError("Audio/Video transcription not supported by current models")
        
        else:
            raise DocumentProcessingError(f"Unsupported file type: {content_type}")
    except Exception as e:
        logger.error(f"Text extraction failed for {filename}: {str(e)}")
        raise DocumentProcessingError(f"Failed to extract text: {str(e)}")