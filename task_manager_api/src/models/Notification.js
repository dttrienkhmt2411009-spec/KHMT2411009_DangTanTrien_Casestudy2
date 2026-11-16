const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema({
  user: { // Người nhận thông báo
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  task: { // ID công việc liên quan (mới thêm)
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Task',
    required: false
  },
  title: {
    type: String,
    required: true
  },
  message: {
    type: String,
    required: true
  },
  isRead: { // Đánh dấu đã đọc hay chưa
    type: Boolean,
    default: false
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.models.Notification || mongoose.model('Notification', notificationSchema);