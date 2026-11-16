import 'package:flutter/material.dart';
import '../../services/task_service.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskService _taskService = TaskService();
  List<dynamic> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks(); // Tự động gọi API khi mở màn hình
  }

  // Hàm gọi API lấy dữ liệu thật
  Future<void> _fetchTasks() async {
    setState(() => _isLoading = true);

    final tasks = await _taskService.getTasks();

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh), // Nút làm mới dữ liệu
            onPressed: _fetchTasks,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
          ? const Center(child: Text('Chưa có công việc nào. Hãy tạo mới!'))
          : ListView.builder(
        itemCount: _tasks.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(
                task['title'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                task['description'] ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Chip(label: Text(task['status'] ?? 'pending')),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TaskDetailScreen(
                      taskId: task['_id'].toString(),
                    ),
                  ),
                );
                // Tự động tải lại danh sách sau khi Sửa / Xóa / Chia sẻ xong
                _fetchTasks();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskCreateScreen()),
          );
          if (result == true) {
            _fetchTasks(); // Tải lại danh sách sau khi thêm thành công
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}