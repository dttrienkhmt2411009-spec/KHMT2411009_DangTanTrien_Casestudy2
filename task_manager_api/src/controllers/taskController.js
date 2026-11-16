const Task = require('../models/task');
const User = require('../models/user');
const Notification = require('../models/Notification');
const nodemailer = require('nodemailer');

const transporter = nodemailer.createTransport({
  service: 'gmail',
  auth: {
    user: 'email.cua.ban@gmail.com', // Giữ nguyên email của bạn
    pass: 'mat_khau_ung_dung_16_so'  // Giữ nguyên mật khẩu ứng dụng của bạn
  }
});

// 1. Hàm Share Task
exports.shareTask = async (req, res) => {
  try {
    const taskId = req.params.id;
    const { email, role } = req.body;

    const userToShare = await User.findOne({ email: email });
    if (!userToShare) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy người dùng với email này' });
    }

    const task = await Task.findById(taskId);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Không tìm thấy công việc' });
    }

    const existingAssigneeIndex = task.assignees.findIndex(
      a => a.user.toString() === userToShare._id.toString()
    );

    if (existingAssigneeIndex !== -1) {
      task.assignees[existingAssigneeIndex].role = role;
    } else {
      task.assignees.push({ user: userToShare._id, role: role });
    }

    await task.save();

    // Tạo thông báo có gắn kèm ID của Task
    const newNotification = new Notification({
      user: userToShare._id,
      task: task._id,
      title: 'Công việc mới được chia sẻ',
      message: `Bạn vừa được cấp quyền ${role} cho công việc "${task.title}". Hãy kiểm tra ngay!`,
      isRead: false
    });
    await newNotification.save();

    const mailOptions = {
      from: 'email.cua.ban@gmail.com',
      to: email,
      subject: `Thông báo: Bạn vừa được giao công việc "${task.title}"`,
      html: `
        <div style="font-family: Arial, padding: 20px; border: 1px solid #ddd; border-radius: 8px;">
          <h2 style="color: #2c3e50;">Xin chào,</h2>
          <p>Bạn vừa được chia sẻ một công việc trên ứng dụng Task Manager.</p>
          <ul>
            <li><b>Tên công việc:</b> ${task.title}</li>
            <li><b>Quyền hạn:</b> <span style="color: red; text-transform: uppercase;">${role}</span></li>
          </ul>
          <p>Vui lòng mở ứng dụng để kiểm tra.</p>
        </div>
      `
    };

    transporter.sendMail(mailOptions, (error, info) => {
      if (error) console.error("🔴 Lỗi gửi email: ", error);
      else console.log("🟢 Đã gửi email: ", info.response);
    });

    res.status(200).json({
      success: true,
      message: 'Chia sẻ thành công và đã gửi thông báo!'
    });

  } catch (error) {
    console.error("🔴 Lỗi API shareTask: ", error);
    res.status(500).json({ success: false, message: 'Lỗi server', error: error.message });
  }
};

// 2. Hàm lấy danh sách thông báo
exports.getNotifications = async (req, res) => {
  try {
    const notifications = await Notification.find({ user: req.user.id }).sort({ createdAt: -1 });
    res.status(200).json({ success: true, notifications: notifications });
  } catch (error) {
    console.error("🔴 Lỗi API getNotifications: ", error);
    res.status(500).json({ success: false, message: 'Lỗi server khi lấy thông báo', error: error.message });
  }
};

// 3. Hàm đánh dấu thông báo đã đọc (Xóa chấm đỏ)
exports.markNotificationAsRead = async (req, res) => {
  try {
    const notiId = req.params.id;
    await Notification.findByIdAndUpdate(notiId, { isRead: true });
    res.status(200).json({ success: true, message: 'Đã đánh dấu đã đọc' });
  } catch (error) {
    console.error("🔴 Lỗi API markNotificationAsRead: ", error);
    res.status(500).json({ success: false, message: 'Lỗi server', error: error.message });
  }
};