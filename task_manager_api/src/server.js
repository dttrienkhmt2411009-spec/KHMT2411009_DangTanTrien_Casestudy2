require('dotenv').config(); // Load các biến từ file .env
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const app = express();

app.use(cors());
app.use(express.json());

// Thiết lập kết nối với MongoDB
mongoose.connect(process.env.MONGO_URI)
  .then(() => console.log('🟢 Kết nối MongoDB thành công!'))
  .catch((err) => {
    console.error('🔴 Lỗi kết nối MongoDB:', err.message);
    process.exit(1); // Dừng server nếu không kết nối được DB
  });

// Giữ lại API test tạm thời
app.post('/api/auth/register', (req, res) => {
  console.log("==> 🚀 NHẬN ĐƯỢC DATA TỪ FLUTTER:", req.body);
  res.status(201).json({ message: "Kết nối thành công!" });
});
// API Đăng nhập (Login)
app.post('/api/auth/login', (req, res) => {
  console.log("==> 🚀 NHẬN ĐƯỢC DATA LOGIN:", req.body);

  // Giả lập kiểm tra email/password (sau này bạn sẽ query từ MongoDB thật)
  const { email, password } = req.body;
  if (email && password) {
    // Trả về HTTP 200 và một token giả để Flutter lưu vào SharedPreferences
    res.status(200).json({
      message: "Đăng nhập thành công!",
      token: "day_la_mot_doan_token_gia_lap_12345"
    });
  } else {
    res.status(401).json({ message: "Thiếu thông tin đăng nhập" });
  }
});

// API Lấy danh sách công việc (Tasks)
app.get('/api/tasks', (req, res) => {
  console.log("==> 🚀 FLUTTER YÊU CẦU LẤY TASKS, Token gửi kèm là:", req.headers.authorization);

  // Trả về danh sách dữ liệu mẫu để Flutter hiển thị lên màn hình
  res.status(200).json({
    data: [
      { title: "Học Flutter", description: "Làm giao diện đăng nhập", isCompleted: true },
      { title: "Viết Backend Node.js", description: "Tạo API login và lấy data", isCompleted: false }
    ]
  });
});
const PORT = process.env.PORT || 3000;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`✅ Server đang chạy tại cổng ${PORT}`);
});