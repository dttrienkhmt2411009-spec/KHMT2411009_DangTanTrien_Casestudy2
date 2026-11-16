require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const jwt = require('jsonwebtoken');

// 1. IMPORT MODELS
const User = require('./models/user');
const Task = require('./models/task');

const app = express();

// 2. MIDDLEWARE CƠ BẢN
app.use(cors());
app.use(express.json());

// 3. CỐ ĐỊNH CẤU HÌNH PORT 3000
const PORT = 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'secretkey_taskmanager_123';

// 4. KẾT NỐI MONGODB (Đọc từ file .env)
const dbURI = process.env.MONGO_URI;

mongoose.connect(dbURI)
  .then(() => console.log('🟢 Kết nối MongoDB thành công!'))
  .catch((err) => console.log('🔴 Lỗi kết nối MongoDB:', err));

// 5. MIDDLEWARE XÁC THỰC TOKEN
const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) return res.status(401).json({ message: 'Không tìm thấy Token xác thực' });

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) return res.status(403).json({ message: 'Token hết hạn hoặc không hợp lệ' });
    req.user = user;
    next();
  });
};

// ==========================================
//                 API ROUTES
// ==========================================

// --- API AUTH (Đăng ký) ---
app.post('/api/auth/register', async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ message: 'Email này đã được sử dụng' });
    }

    // Đã sửa lại tên các trường cho khớp chính xác với userSchema của bạn
    const newUser = new User({
      fullName: fullName,
      email: email,
      passwordHash: password
    });

    await newUser.save();
    res.status(201).json({ message: 'Đăng ký thành công' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- API AUTH (Đăng nhập) ---
app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    const user = await User.findOne({ email });

    // Đã sửa đối chiếu mật khẩu với trường passwordHash
    if (!user || user.passwordHash !== password) {
      return res.status(400).json({ message: 'Email hoặc mật khẩu không đúng' });
    }

    const token = jwt.sign({ id: user._id, email: user.email }, JWT_SECRET, { expiresIn: '7d' });

    // Trả về fullName thay vì username
    res.status(200).json({
      token,
      user: { id: user._id, email: user.email, fullName: user.fullName }
    });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- API TASK CRUD ---
// Lấy danh sách công việc (Read All)
app.get('/api/tasks', verifyToken, async (req, res) => {
  try {
    const userId = req.user.id;
    const tasks = await Task.find({
      $or: [
        { owner: userId },
        { 'assignees.user': userId }
      ]
    }).sort({ createdAt: -1 });
    res.status(200).json(tasks);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Tạo công việc mới (Create)
app.post('/api/tasks', verifyToken, async (req, res) => {
  try {
    const { title, description, status, priority, dueDate } = req.body;
    if (!title) return res.status(400).json({ message: 'Tiêu đề không được để trống' });

    const newTask = new Task({
      title,
      description,
      status: status || 'pending',
      priority: priority || 'medium',
      dueDate,
      owner: req.user.id
    });

    await newTask.save();
    res.status(201).json(newTask);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Xem chi tiết một công việc
app.get('/api/tasks/:id', verifyToken, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id)
      .populate('owner', 'username email')
      .populate('assignees.user', 'username email');
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });
    res.status(200).json(task);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Cập nhật công việc (Update)
app.put('/api/tasks/:id', verifyToken, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    const isOwner = task.owner.toString() === req.user.id;
    const assignee = task.assignees.find(a => a.user.toString() === req.user.id);
    const isEditor = assignee && assignee.role === 'editor';

    if (!isOwner && !isEditor) {
      return res.status(403).json({ message: 'Bạn không có quyền chỉnh sửa công việc này' });
    }

    const updatedTask = await Task.findByIdAndUpdate(req.params.id, req.body, { new: true });
    res.status(200).json(updatedTask);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Xóa công việc (Delete)
app.delete('/api/tasks/:id', verifyToken, async (req, res) => {
  try {
    const task = await Task.findById(req.params.id);
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    if (task.owner.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Chỉ người tạo mới có quyền xóa' });
    }

    await Task.findByIdAndDelete(req.params.id);
    res.status(200).json({ message: 'Xóa thành công' });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// --- API TÌM KIẾM & CHIA SẺ ---
// Tìm user theo email
app.get('/api/users/search', verifyToken, async (req, res) => {
  try {
    const { email } = req.query;
    if (!email) return res.status(400).json({ message: 'Vui lòng nhập email' });

    const user = await User.findOne({ email }).select('_id email username');
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });

    res.status(200).json(user);
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// Chia sẻ công việc
app.post('/api/tasks/:id/share', verifyToken, async (req, res) => {
  try {
    const { email, role } = req.body;
    const taskId = req.params.id;

    const task = await Task.findById(taskId);
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    if (task.owner.toString() !== req.user.id) {
      return res.status(403).json({ message: 'Chỉ người tạo mới có quyền chia sẻ' });
    }

    const targetUser = await User.findOne({ email });
    if (!targetUser) return res.status(404).json({ message: 'Email không tồn tại' });

    if (targetUser._id.toString() === req.user.id) {
      return res.status(400).json({ message: 'Bạn không thể tự chia sẻ cho chính mình' });
    }

    const existingIndex = task.assignees.findIndex(a => a.user.toString() === targetUser._id.toString());
    if (existingIndex > -1) {
      task.assignees[existingIndex].role = role;
    } else {
      task.assignees.push({ user: targetUser._id, role });
    }

    await task.save();
    res.status(200).json({ message: 'Chia sẻ thành công', task });
  } catch (err) {
    res.status(500).json({ message: err.message });
  }
});

// ==========================================
//              KHỞI ĐỘNG SERVER
// ==========================================
app.listen(PORT, () => {
  console.log(`🚀 Server đang chạy tại http://localhost:${PORT}`);
});