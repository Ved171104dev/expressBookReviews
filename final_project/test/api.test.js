const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const app = require('../index.js');
const {
  getAllBooks,
  getBookByISBN,
  getBooksByAuthor,
  getBooksByTitle
} = require('../router/axios_client.js');

let server;
let baseUrl;

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
});

const request = async (path, options = {}) => {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      'content-type': 'application/json',
      ...options.headers
    }
  });
  const body = await response.json();
  return { response, body };
};

test('public book retrieval and search endpoints work', async () => {
  const all = await request('/');
  assert.equal(all.response.status, 200);
  assert.equal(Object.keys(all.body).length, 10);

  const isbn = await request('/isbn/1');
  assert.equal(isbn.body.title, 'Things Fall Apart');

  const author = await request('/author/Jane%20Austen');
  assert.equal(author.body['8'].title, 'Pride and Prejudice');

  const title = await request('/title/Pride%20and%20Prejudice');
  assert.equal(title.body['8'].author, 'Jane Austen');

  const reviews = await request('/review/1');
  assert.deepEqual(reviews.body, {});
});

test('registration, JWT login, and review lifecycle work', async () => {
  const username = `reader-${Date.now()}`;
  const credentials = { username, password: 'correct-horse-battery-staple' };

  const registration = await request('/register', {
    method: 'POST',
    body: JSON.stringify(credentials)
  });
  assert.equal(registration.response.status, 201);

  const duplicate = await request('/register', {
    method: 'POST',
    body: JSON.stringify(credentials)
  });
  assert.equal(duplicate.response.status, 409);

  const login = await request('/customer/login', {
    method: 'POST',
    body: JSON.stringify(credentials)
  });
  assert.equal(login.response.status, 200);
  assert.ok(login.body.accessToken);

  const authHeaders = { authorization: `Bearer ${login.body.accessToken}` };
  const added = await request('/customer/auth/review/1', {
    method: 'PUT',
    headers: authHeaders,
    body: JSON.stringify({ review: 'A timeless novel.' })
  });
  assert.equal(added.response.status, 200);
  assert.equal(added.body.reviews[username], 'A timeless novel.');

  const visible = await request('/review/1');
  assert.equal(visible.body[username], 'A timeless novel.');

  const deleted = await request('/customer/auth/review/1', {
    method: 'DELETE',
    headers: authHeaders
  });
  assert.equal(deleted.response.status, 200);

  const afterDelete = await request('/review/1');
  assert.equal(afterDelete.body[username], undefined);
});

test('protected review routes reject unauthenticated requests', async () => {
  const result = await request('/customer/auth/review/1', {
    method: 'PUT',
    body: JSON.stringify({ review: 'Should not be accepted.' })
  });
  assert.equal(result.response.status, 401);
});

test('Axios asynchronous tasks return the expected data', async () => {
  const all = await getAllBooks(baseUrl);
  assert.equal(Object.keys(all).length, 10);

  const isbn = await getBookByISBN('2', baseUrl);
  assert.equal(isbn.title, 'Fairy tales');

  const author = await getBooksByAuthor('Jane Austen', baseUrl);
  assert.equal(author['8'].title, 'Pride and Prejudice');

  const title = await getBooksByTitle('The Divine Comedy', baseUrl);
  assert.equal(title['3'].author, 'Dante Alighieri');
});
