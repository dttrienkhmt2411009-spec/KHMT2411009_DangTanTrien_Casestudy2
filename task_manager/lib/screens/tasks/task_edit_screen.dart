import 'package:flutter/material.dart';
import '../../services/task_service.dart';

class TaskEditScreen extends StatefulWidget {
  final dynamic task; // Nhận dữ liệu task từ màn hình chi tiết truyền sang

  const TaskEditScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final TaskService _taskService = TaskService();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _status;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Gán dữ liệu cũ vào các ô nhập liệu
    _titleController = TextEditingController(text: widget.task['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.task['description'] ?? '');
    _status = widget.task['status'] ?? 'pending';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final updateData = {
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'status': _status,
    };

    final success = await _taskService.updateTask(widget.task['_id'], updateData);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật thành công!')),
      );
      Navigator.pop(context, true); // Trả về true để màn hình chi tiết load lại
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có lỗi xảy ra, vui lòng thử lại')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa công việc')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tiêu đề'),
                validator: (value) => value!.isEmpty ? 'Vui lòng nhập tiêu đề' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Mô tả (tùy chọn)'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Trạng thái'),
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Chưa bắt đầu')),
                  DropdownMenuItem(value: 'in-progress', child: Text('Đang tiến hành')),
                  DropdownMenuItem(value: 'completed', child: Text('Đã hoàn thành')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _status = value);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitForm,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Lưu thay đổi'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}