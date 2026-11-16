// models/Task.js
const mongoose = require('mongoose');

const taskSchema = new mongoose.Schema({
  title: { type: String, required: true },
  description: { type: String },
  status: { type: String, default: 'pending' }, // pending, in-progress, completed

  // Người tạo ra công việc (Có toàn quyền: Xóa, Sửa)
  owner: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },

  // Danh sách những người được giao việc / chia sẻ
  assignees: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    role: { type: String, enum: ['viewer', 'editor'], default: 'viewer' } // Phân quyền
  }]
}, { timestamps: true });

module.exports = mongoose.models.Task || mongoose.model('Task', taskSchema);