const express = require('express');
const cors = require('cors');

const app = express();

// Middleware xử lý JSON và CORS
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Route kiểm tra server
app.get('/api', (req, res) => {
  res.json({ message: 'Task Manager API is running...' });
});

module.exports = app;