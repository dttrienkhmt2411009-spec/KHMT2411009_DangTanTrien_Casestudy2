import 'package:flutter/material.dart';
import '../../models/task.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  // Dữ liệu giả để test UI
  final List<Task> mockTasks = [
    Task(
      id: '1',
      title: 'Thiết kế UI/UX',
      description: 'Làm giao diện cho app Task Manager',
      status: 'in_progress',
      priority: 'high',
      dueDate: DateTime.now().add(const Duration(days: 2)),
    ),
    Task(
      id: '2',
      title: 'Viết API Backend',
      description: 'Khởi tạo Node.js và MongoDB',
      status: 'todo',
      priority: 'medium',
      dueDate: DateTime.now().add(const Duration(days: 5)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh sách công việc'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // Chuyển sang màn hình Profile sau
            },
          )
        ],
      ),
      body: ListView.builder(
        itemCount: mockTasks.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final task = mockTasks[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(task.description),
              trailing: Chip(label: Text(task.status)),
              onTap: () {
                // Chuyển sang màn hình Chi tiết công việc
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Chuyển sang màn hình Thêm công việc
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}