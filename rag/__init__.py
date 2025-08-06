# RAG package - Medical Question Answering System
"""
Medical RAG (Retrieval Augmented Generation) Package

This package provides medical question answering capabilities using:
- LLM (Large Language Model) for text generation
- ChromaDB for vector search and retrieval
- Harrison's Endocrinology medical knowledge base
"""

from .rag import answer_question, add_to_db

__version__ = "1.0.0"
__author__ = "ym"
