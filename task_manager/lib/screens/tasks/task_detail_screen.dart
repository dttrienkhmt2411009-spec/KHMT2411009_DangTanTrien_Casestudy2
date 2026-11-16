import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/task_service.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TaskService _taskService = TaskService();
  Map<String, dynamic>? _task;
  String? _currentUserId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Giải mã jwt_token và bắt mọi kiểu đặt tên ID của Backend (id, _id, userId, sub, user.id)
  Future<String?> _getCurrentUserIdFromToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token == null) return null;

    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;

      dynamic rawId = map['id'] ?? map['_id'] ?? map['userId'] ?? map['sub'];
      if (rawId == null && map['user'] is Map) {
        rawId = map['user']['id'] ?? map['user']['_id'];
      }
      return rawId?.toString();
    } catch (e) {
      print("🔴 Lỗi giải mã token: $e");
      return null;
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final userId = await _getCurrentUserIdFromToken();
    final taskData = await _taskService.getTaskById(widget.taskId);

    print("🔍 User ID hiện tại: $userId");
    print("🔍 Owner của Task: ${taskData?['owner']}");

    if (mounted) {
      setState(() {
        _currentUserId = userId;
        _task = taskData;
        _isLoading = false;
      });
    }
  }

  // --- KIỂM TRA PHÂN QUYỀN ---
  bool get _isOwner {
    if (_task == null || _currentUserId == null) return false;
    final owner = _task!['owner'];
    final ownerId = owner is Map
        ? (owner['_id'] ?? owner['id'])?.toString()
        : owner?.toString();
    return ownerId != null && ownerId.trim() == _currentUserId!.trim();
  }

  bool get _canEdit {
    if (_isOwner) return true;
    if (_task == null || _currentUserId == null) return false;

    final assignees = (_task!['assignees'] as List<dynamic>?) ?? [];
    for (final item in assignees) {
      if (item is Map) {
        final userObj = item['user'];
        final userId = userObj is Map
            ? (userObj['_id'] ?? userObj['id'])?.toString()
            : userObj?.toString();
        if (userId != null &&
            userId.trim() == _currentUserId!.trim() &&
            item['role'] == 'editor') {
          return true;
        }
      }
    }
    return false;
  }

  String get _myRoleLabel {
    if (_isOwner) return 'Chủ sở hữu (Toàn quyền)';
    if (_canEdit) return 'Editor (Được chỉnh sửa)';
    return 'Viewer (Chỉ xem)';
  }

  // --- 1. DIALOG SỬA CÔNG VIỆC ---
  void _showEditDialog() {
    final titleCtrl = TextEditingController(text: _task!['title'] ?? '');
    final descCtrl = TextEditingController(text: _task!['description'] ?? '');
    String status = _task!['status'] ?? 'pending';
    String priority = _task!['priority'] ?? 'medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cập nhật công việc'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Tiêu đề'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Mô tả'),
                  maxLines: 3,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: ['pending', 'in_progress', 'completed'].contains(status)
                      ? status
                      : 'pending',
                  decoration: const InputDecoration(labelText: 'Trạng thái'),
                  items: const [
                    DropdownMenuItem(value: 'pending', child: Text('Chờ xử lý (pending)')),
                    DropdownMenuItem(value: 'in_progress', child: Text('Đang làm (in_progress)')),
                    DropdownMenuItem(value: 'completed', child: Text('Hoàn thành (completed)')),
                  ],
                  onChanged: (val) => setDialogState(() => status = val!),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: ['low', 'medium', 'high'].contains(priority)
                      ? priority
                      : 'medium',
                  decoration: const InputDecoration(labelText: 'Độ ưu tiên'),
                  items: const [
                    DropdownMenuItem(value: 'low', child: Text('Thấp (low)')),
                    DropdownMenuItem(value: 'medium', child: Text('Trung bình (medium)')),
                    DropdownMenuItem(value: 'high', child: Text('Cao (high)')),
                  ],
                  onChanged: (val) => setDialogState(() => priority = val!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);

                final ok = await _taskService.updateTask(widget.taskId, {
                  'title': titleCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'status': status,
                  'priority': priority,
                });

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ok ? 'Đã cập nhật công việc' : 'Cập nhật thất bại')),
                );
                if (ok) _loadData();
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 2. DIALOG CHIA SẺ / GIAO VIỆC NHIỀU NGƯỜI ---
  void _showShareDialog() {
    final emailCtrl = TextEditingController();
    String selectedRole = 'viewer';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Chia sẻ & Giao việc'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email người nhận',
                  hintText: 'nhapemail@gmail.com',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Quyền truy cập'),
                items: const [
                  DropdownMenuItem(value: 'viewer', child: Text('Viewer (Chỉ xem)')),
                  DropdownMenuItem(value: 'editor', child: Text('Editor (Được sửa)')),
                ],
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;
                Navigator.pop(ctx);

                final res = await _taskService.shareTask(widget.taskId, email, selectedRole);
                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']),
                    backgroundColor: res['success'] == true ? Colors.green : Colors.red,
                  ),
                );
                if (res['success'] == true) _loadData();
              },
              child: const Text('Chia sẻ'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. XÁC NHẬN XÓA ---
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa công việc'),
        content: const Text('Bạn có chắc chắn muốn xóa công việc này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              final ok = await _taskService.deleteTask(widget.taskId);
              if (!mounted) return;

              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Đã xóa công việc')),
                );
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Bạn không có quyền xóa công việc này')),
                );
              }
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết công việc')),
        body: const Center(child: Text('Không tải được dữ liệu công việc')),
      );
    }

    final assignees = (_task!['assignees'] as List<dynamic>?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết công việc'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              _task!['title'] ?? '',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(
                label: Text('Quyền của bạn: $_myRoleLabel'),
                backgroundColor: _isOwner
                    ? Colors.blue.shade100
                    : (_canEdit ? Colors.orange.shade100 : Colors.grey.shade200),
              ),
            ),
            const SizedBox(height: 12),

            // --- CỤM NÚT CHỨC NĂNG HIỂN THỊ TRỰC TIẾP TRÊN GIAO DIỆN ---
            if (_canEdit || _isOwner)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (_canEdit)
                      ElevatedButton.icon(
                        onPressed: _showEditDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Sửa'),
                      ),
                    if (_isOwner) ...[
                      ElevatedButton.icon(
                        onPressed: _showShareDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Chia sẻ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _confirmDelete,
                        icon: const Icon(Icons.delete),
                        label: const Text('Xóa'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            Text('Trạng thái: ${_task!['status']}  |  Ưu tiên: ${_task!['priority']}'),
            const Divider(height: 24),
            const Text('Mô tả:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_task!['description']?.toString().isNotEmpty == true
                ? _task!['description']
                : 'Không có mô tả'),
            const Divider(height: 24),
            const Text('Người được giao / chia sẻ:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (assignees.isEmpty)
              const Text('Chưa chia sẻ cho ai')
            else
              ...assignees.map((item) {
                final user = item['user'];
                final email = user is Map ? (user['email'] ?? '') : user.toString();
                final role = item['role'] ?? 'viewer';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person),
                  title: Text(email),
                  trailing: Chip(label: Text(role.toUpperCase())),
                );
              }),
          ],
        ),
      ),
    );
  }
}