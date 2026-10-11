const express = require('express');
const jwt = require('jsonwebtoken');
const session = require('express-session');
const customer_routes = require('./router/auth_users.js').authenticated;
const genl_routes = require('./router/general.js').general;

const app = express();
const JWT_SECRET = process.env.JWT_SECRET || 'fingerprint_customer';

app.use(express.json());

app.use('/customer', session({
  secret: process.env.SESSION_SECRET || 'fingerprint_customer',
  resave: false,
  saveUninitialized: false,
  cookie: { httpOnly: true, sameSite: 'lax' }
}));

app.use('/customer/auth', (req, res, next) => {
  const authorizationHeader = req.get('authorization');
  const bearerToken = authorizationHeader?.startsWith('Bearer ')
    ? authorizationHeader.slice(7)
    : undefined;
  const token = bearerToken || req.session.authorization?.accessToken;

  if (!token) {
    return res.status(401).json({ message: 'Authentication token is required.' });
  }

  try {
    req.user = jwt.verify(token, JWT_SECRET);
    return next();
  } catch (error) {
    return res.status(401).json({ message: 'Invalid or expired authentication token.' });
  }
});

app.use('/customer', customer_routes);
app.use('/', genl_routes);

const PORT = Number(process.env.PORT) || 5000;
if (require.main === module) {
  app.listen(PORT, () => console.log(`Server is running on port ${PORT}`));
}

module.exports = app;
