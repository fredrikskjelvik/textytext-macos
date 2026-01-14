# Realm Objects

These are the objects that represent Realm objects. They contain data about a specific thing.

## Overview

- ``FolderDB`` -> A folder containing ``DocumentDB``'s
- ``DocumentDB`` -> A document with a book (optional), notes, flashcards and outline items
    - ``BookDB`` -> A book, either PDF or ePub
    - ``FlashcardDB`` -> A single flashcard
    - ``NoteDB`` -> User's notes about this document
        - ``NoteChapterDB`` -> Note chapters are stored separately. Their contents (blocks etc.) are separate and they are displayed in separate ``TextView``'s.
    - ``OutlineItemDB`` -> An outline item in the table of contents. Shared between notes, flashcards, book.

## Topics

### Document
- ``DocumentDB``
- ``OutlineItemDB``

### Book
- ``BookDB``

### Flashcard
- ``FlashcardDB``

### Note
- ``NoteDB``
- ``NoteChapterDB``

### Other
- ``FolderDB``
