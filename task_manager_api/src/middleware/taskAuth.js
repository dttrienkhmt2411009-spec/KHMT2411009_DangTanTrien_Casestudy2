// middleware/taskAuth.js
const Task = require('../models/Task');

const checkTaskPermission = (requiredRole) => {
  return async (req, res, next) => {
    try {
      const taskId = req.params.id;
      const userId = req.user.id; // Lấy từ token đăng nhập

      const task = await Task.findById(taskId);
      if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

      // 1. Nếu là Owner -> Luôn có toàn quyền (Bỏ qua check)
      if (task.owner.toString() === userId) {
        req.task = task; // Truyền task đi tiếp
        return next();
      }

      // 2. Kiểm tra xem user có nằm trong danh sách assignees không
      const assignee = task.assignees.find(a => a.user.toString() === userId);

      if (!assignee) {
        return res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
      }

      // 3. Kiểm tra cấp độ quyền (Viewer vs Editor)
      if (requiredRole === 'editor' && assignee.role !== 'editor') {
        return res.status(403).json({ message: 'Bạn chỉ có quyền xem, không được phép chỉnh sửa' });
      }

      req.task = task;
      next();
    } catch (error) {
      res.status(500).json({ message: 'Lỗi server' });
    }
  };
};

module.exports = checkTaskPermission;