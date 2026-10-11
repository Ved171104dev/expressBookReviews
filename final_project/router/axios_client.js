const axios = require('axios');

const defaultBaseUrl = process.env.BOOKS_API_URL || 'http://localhost:5000';

const createClient = (baseUrl = defaultBaseUrl) => axios.create({ baseURL: baseUrl });

// Task 10: retrieve all books with async/await.
const getAllBooks = async (baseUrl) => {
  const response = await createClient(baseUrl).get('/');
  return response.data;
};

// Task 11: retrieve a book by ISBN using an explicit Promise chain.
const getBookByISBN = (isbn, baseUrl) =>
  createClient(baseUrl)
    .get(`/isbn/${encodeURIComponent(isbn)}`)
    .then((response) => response.data);

// Task 12: retrieve books by author asynchronously.
const getBooksByAuthor = async (author, baseUrl) => {
  const response = await createClient(baseUrl).get(`/author/${encodeURIComponent(author)}`);
  return response.data;
};

// Task 13: retrieve books by title asynchronously.
const getBooksByTitle = async (title, baseUrl) => {
  const response = await createClient(baseUrl).get(`/title/${encodeURIComponent(title)}`);
  return response.data;
};

module.exports = {
  getAllBooks,
  getBookByISBN,
  getBooksByAuthor,
  getBooksByTitle
};
