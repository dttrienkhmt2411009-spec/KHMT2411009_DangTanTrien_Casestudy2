exports.getNotifications = async (req, res) => {
  try {
    // Giả sử bạn lấy userId từ token (req.userId) sau khi qua middleware verifyToken
    const userId = req.userId; // Cần có auth middleware để lấy ID người đang đăng nhập

    const notifications = await Notification.find({ user: userId }).sort({ createdAt: -1 });
    res.status(200).json({ success: true, notifications });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Lỗi server', error: error.message });
  }
};