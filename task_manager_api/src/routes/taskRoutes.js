const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController'); // Import file controller ở Bước 1
// const { verifyToken } = require('../middlewares/authMiddleware'); // Nếu có bảo mật token thì mở cái này

// ... Các API get, post, put, delete công việc khác của bạn giữ nguyên ...

// Thêm dòng này để xử lý nút "Chia sẻ" từ Flutter truyền lên
router.post('/:id/share', taskController.shareTask);
// (Nếu project bạn bắt buộc phải có token mới gọi được, đổi thành: router.post('/:id/share', verifyToken, taskController.shareTask); )

module.exports = router;