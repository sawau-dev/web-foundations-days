# Library Books REST API

This REST API manages books in a library.

## 1. List all books

- **Method:** GET
- **Path:** `/books`
- **Description:** Returns all books in the library.
- **Success status:** `200 OK`

Example request:

GET /books

## 2. Get one book

- **Method:** GET
- **Path:** `/books/{id}`
- **Description:** Returns one book by its ID.
- **Success status:** `200 OK`

Example request:

GET /books/42

Example response:

{
  "id": 42,
  "title": "The Great Gatsby",
  "author": "F. Scott Fitzgerald",
  "year": 1925
}
## 3. Create a book

- **Method:** POST
- **Path:** `/books`
- **Description:** Creates a new book.
- **Success status:** `201 Created`

Example request body:

{
  "title": "Things Fall Apart",
  "author": "Chinua Achebe",
  "year": 1958
}

## 4. Update a book

- **Method:** PUT
- **Path:** `/books/{id}`
- **Description:** Updates an existing book.
- **Success status:** `200 OK`

Example request:

PUT /books/42

Example request body:

{
  "title": "The Great Gatsby - Revised Edition",
  "author": "F. Scott Fitzgerald",
  "year": 1925
}
## 5. Delete a book

- **Method:** DELETE
- **Path:** `/books/{id}`
- **Description:** Deletes a book by its ID.
- **Success status:** `204 No Content`

Example request:

DELETE /books/42

## 6. List books by author

- **Method:** GET
- **Path:** `/books?author={author}`
- **Description:** Returns books written by the specified author.
- **Success status:** `200 OK`

Example request:

GET /books?author=Chinua%20Achebe

Example response:

[
  {
    "id": 2,
    "title": "Things Fall Apart",
    "author": "Chinua Achebe",
    "year": 1958
  }
]

## Error Responses

### 400 Bad Request

Returned when the request contains invalid or missing data.

Example:

POST /books

Invalid request body:

{
  "title": "",
  "author": "",
  "year": "invalid"
}

Response:

{
  "error": "Bad Request",
  "message": "Invalid book data."
}

### 404 Not Found

Returned when the requested book does not exist.

Example:

GET /books/9999

Response:

{
  "error": "Not Found",
  "message": "Book with ID 9999 was not found."
}
