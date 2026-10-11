const express = require('express');
const axios = require('axios');
const books = require('./booksdb.js');
const isValid = require('./auth_users.js').isValid;
const users = require('./auth_users.js').users;
const public_users = express.Router();

public_users.post('/register', (req, res) => {
  const { username, password } = req.body;

  if (typeof username !== 'string' || !username.trim() ||
      typeof password !== 'string' || !password) {
    return res.status(400).json({ message: 'Username and password are required.' });
  }

  const normalizedUsername = username.trim();
  if (isValid(normalizedUsername)) {
    return res.status(409).json({ message: 'Username already exists.' });
  }

  users.push({ username: normalizedUsername, password });
  return res.status(201).json({ message: 'User registered successfully.' });
});

// Get the book list available in the shop
public_users.get('/', (req, res) => {
  return res.status(200).json(books);
});

// Get book details based on ISBN
public_users.get('/isbn/:isbn', (req, res) => {
  const book = books[req.params.isbn];
  if (!book) {
    return res.status(404).json({ message: 'Book not found.' });
  }

  return res.status(200).json(book);
});

// Get book details based on author
public_users.get('/author/:author', (req, res) => {
  const author = req.params.author.trim().toLowerCase();
  const matches = Object.fromEntries(
    Object.entries(books).filter(([, book]) => book.author.toLowerCase() === author)
  );

  if (Object.keys(matches).length === 0) {
    return res.status(404).json({ message: 'No books found for that author.' });
  }

  return res.status(200).json(matches);
});

// Get all books based on title
public_users.get('/title/:title', (req, res) => {
  const title = req.params.title.trim().toLowerCase();
  const matches = Object.fromEntries(
    Object.entries(books).filter(([, book]) => book.title.toLowerCase() === title)
  );

  if (Object.keys(matches).length === 0) {
    return res.status(404).json({ message: 'No books found with that title.' });
  }

  return res.status(200).json(matches);
});

// Get book reviews
public_users.get('/review/:isbn', (req, res) => {
  const book = books[req.params.isbn];
  if (!book) {
    return res.status(404).json({ message: 'Book not found.' });
  }

  return res.status(200).json(book.reviews);
});

const BASE_URL = process.env.BOOKS_API_URL || 'http://localhost:5000';

// Task 11: retrieve all books using Axios and async/await.
async function getAllBooks(baseUrl = BASE_URL) {
  const response = await axios.get(baseUrl);
  return response.data;
}

// Retrieve a book by ISBN using Axios and a Promise callback.
function getBookByISBN(isbn, baseUrl = BASE_URL) {
  return axios
    .get(`${baseUrl}/isbn/${encodeURIComponent(isbn)}`)
    .then((response) => response.data);
}

// Retrieve books by author using Axios and async/await.
async function getBooksByAuthor(author, baseUrl = BASE_URL) {
  const response = await axios.get(
    `${baseUrl}/author/${encodeURIComponent(author)}`
  );
  return response.data;
}

// Retrieve books by title using Axios and async/await.
async function getBooksByTitle(title, baseUrl = BASE_URL) {
  const response = await axios.get(
    `${baseUrl}/title/${encodeURIComponent(title)}`
  );
  return response.data;
}

module.exports.general = public_users;
module.exports.axiosBookClient = {
  getAllBooks,
  getBookByISBN,
  getBooksByAuthor,
  getBooksByTitle
};
