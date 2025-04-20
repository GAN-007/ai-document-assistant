import pytest
from app.core.document_processor import extract_text, improve_text
from io import BytesIO
import docx

@pytest.mark.asyncio
async def test_extract_text_txt():
    content = b"This is a test."
    text = await extract_text("test.txt", content, "text/plain")
    assert text == "This is a test."

@pytest.mark.asyncio
async def test_extract_text_docx():
    doc = docx.Document()
    doc.add_paragraph("This is a test.")
    buffer = BytesIO()
    doc.save(buffer)
    content = buffer.getvalue()
    text = await extract_text("test.docx", content, "application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    assert "This is a test." in text

@pytest.mark.asyncio
async def test_improve_text():
    text = "This is teh document. It was written by John."
    improved_text, suggestions = await improve_text(text)
    assert "the" in improved_text
    assert any(s.original_text == "teh" and s.improved_text == "the" for s in suggestions)
    assert any("passive voice" in s.reason.lower() for s in suggestions)