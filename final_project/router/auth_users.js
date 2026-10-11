const express = require('express');
const jwt = require('jsonwebtoken');
const books = require('./booksdb.js');
const regd_users = express.Router();

const users = [];
const JWT_SECRET = process.env.JWT_SECRET || 'fingerprint_customer';

// Returns true when the username is already registered.
const isValid = (username) => users.some((user) => user.username === username);

const authenticatedUser = (username, password) =>
  users.some((user) => user.username === username && user.password === password);

// Only registered users can log in.
regd_users.post('/login', (req, res) => {
  const { username, password } = req.body;

  if (!authenticatedUser(username, password)) {
    return res.status(401).json({ message: 'Invalid username or password.' });
  }

  const accessToken = jwt.sign({ username }, JWT_SECRET, { expiresIn: '1h' });
  req.session.authorization = { accessToken, username };

  return res.status(200).json({
    message: 'User logged in successfully.',
    accessToken
  });
});

// Add or update a book review.
regd_users.put('/auth/review/:isbn', (req, res) => {
  const book = books[req.params.isbn];
  const review = req.body.review ?? req.query.review;

  if (!book) {
    return res.status(404).json({ message: 'Book not found.' });
  }
  if (typeof review !== 'string' || !review.trim()) {
    return res.status(400).json({ message: 'A non-empty review is required.' });
  }

  book.reviews[req.user.username] = review.trim();
  return res.status(200).json({
    message: 'Review added or updated successfully.',
    reviews: book.reviews
  });
});

// Delete the authenticated user's review.
regd_users.delete('/auth/review/:isbn', (req, res) => {
  const book = books[req.params.isbn];

  if (!book) {
    return res.status(404).json({ message: 'Book not found.' });
  }
  if (!Object.hasOwn(book.reviews, req.user.username)) {
    return res.status(404).json({ message: 'Review not found.' });
  }

  delete book.reviews[req.user.username];
  return res.status(200).json({ message: 'Review deleted successfully.' });
});

module.exports.authenticated = regd_users;
module.exports.isValid = isValid;
module.exports.authenticatedUser = authenticatedUser;
module.exports.users = users;
