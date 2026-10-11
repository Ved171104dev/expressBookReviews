# Express Book Reviews API

This project provides a complete Express API for browsing books, registering and
authenticating users, and managing book reviews.

## Run locally

```bash
npm install
npm start
```

The API listens on `http://localhost:5000` by default. Set `PORT`, `JWT_SECRET`,
and `SESSION_SECRET` in the environment to override the defaults.

## Public endpoints

- `GET /` - retrieve all books
- `GET /isbn/:isbn` - retrieve a book by ISBN
- `GET /author/:author` - search by author
- `GET /title/:title` - search by title
- `GET /review/:isbn` - retrieve reviews for a book
- `POST /register` - register with `{ "username": "...", "password": "..." }`
- `POST /customer/login` - log in and receive a JWT

## Authenticated review endpoints

Send the token as `Authorization: Bearer <token>`.

- `PUT /customer/auth/review/:isbn` with `{ "review": "..." }`
- `DELETE /customer/auth/review/:isbn`

## Axios tasks and tests

`router/general.js` exports asynchronous Axios functions for retrieving all
books and searching by ISBN, author, and title, as required by Task 11.

```bash
npm test
```
