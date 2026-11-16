import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/task_service.dart';
import '../auth/login_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final TaskService _taskService = TaskService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _allTasks = [];
  bool _isLoading = true;
  String _userEmail = 'Đang tải...';

  // Biến quản lý thông báo
  int _unreadCount = 0;
  List<dynamic> _notifications = [];

  // Biến phục vụ Tìm kiếm & Lọc
  String _searchQuery = '';
  String _filterStatus = 'all';

  // Bảng màu hiện đại (Modern Slate & Indigo)
  static const Color _bgColor = Color(0xFFF8FAFC);
  static const Color _primaryColor = Color(0xFF4F46E5);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _borderColor = Color(0xFFE2E8F0);

  @override
  void initState() {
    super.initState();
    _loadUserEmail();
    _fetchTasks();
    _fetchNotifications();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LẤY EMAIL NGƯỜI DÙNG TỪ BỘ NHỚ HOẶC JWT TOKEN ---
  Future<void> _loadUserEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? email = prefs.getString('user_email') ?? prefs.getString('email');

      if (email == null || email.isEmpty) {
        final token = prefs.getString('jwt_token');
        if (token != null && token.split('.').length == 3) {
          final normalized = base64Url.normalize(token.split('.')[1]);
          final payloadMap = jsonDecode(utf8.decode(base64Url.decode(normalized)));
          email = payloadMap['email']?.toString() ??
              payloadMap['user']?['email']?.toString();
        }
      }

      if (mounted) {
        setState(() {
          _userEmail = (email != null && email.isNotEmpty) ? email : 'Tài khoản của tôi';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _userEmail = 'Tài khoản của tôi');
      }
    }
  }

  // --- XỬ LÝ ĐĂNG XUẤT ---
  Future<void> _handleLogout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_email');
    await prefs.remove('email');

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  // --- HÀM TẢI CÔNG VIỆC ---
  Future<void> _fetchTasks() async {
    if (_allTasks.isEmpty) {
      setState(() => _isLoading = true);
    }
    final tasks = await _taskService.getTasks();
    if (mounted) {
      setState(() {
        _allTasks = tasks;
        _isLoading = false;
      });
    }
  }

  // --- HÀM TẢI THÔNG BÁO ---
  Future<void> _fetchNotifications() async {
    try {
      final notis = await _taskService.getNotifications();
      if (mounted) {
        setState(() {
          _notifications = notis;
          _unreadCount = notis.where((n) => n['isRead'] != true).length;
        });
      }
    } catch (e) {
      print("🔴 LỖI TẢI THÔNG BÁO: $e");
    }
  }

  // --- KÉO XUỐNG ĐỂ LÀM MỚI TOÀN BỘ ---
  Future<void> _onRefresh() async {
    await Future.wait([
      _fetchTasks(),
      _fetchNotifications(),
    ]);
  }

  // --- HÀM ĐÁNH DẤU ĐÃ ĐỌC & TRỪ 1 CHẤM ĐỎ ---
  Future<void> _markAsRead(String notiId) async {
    setState(() {
      for (var n in _notifications) {
        if (n['_id']?.toString() == notiId) {
          n['isRead'] = true;
        }
      }
      _unreadCount = _notifications.where((n) => n['isRead'] != true).length;
    });

    await _taskService.markNotificationAsRead(notiId);
  }

  // --- ĐÁNH DẤU ĐÃ ĐỌC TẤT CẢ THÔNG BÁO CỦA 1 TASK ---
  Future<void> _markTaskNotificationsAsRead(String taskId) async {
    final unreadForTask = _notifications
        .where((n) => n['isRead'] != true && _extractTaskId(n) == taskId)
        .toList();

    for (var n in unreadForTask) {
      await _markAsRead(n['_id'].toString());
    }
  }

  // --- LẤY ID CÔNG VIỆC TỪ THÔNG BÁO ---
  String? _extractTaskId(dynamic noti) {
    final rawTask = noti['task'];
    if (rawTask != null) {
      if (rawTask is Map) return rawTask['_id']?.toString();
      if (rawTask.toString().isNotEmpty) return rawTask.toString();
    }

    final message = (noti['message'] ?? '').toString();
    final match = RegExp(r'"([^"]+)"').firstMatch(message);
    if (match != null) {
      final taskTitle = match.group(1);
      for (var t in _allTasks) {
        if (t['title']?.toString() == taskTitle) {
          return t['_id']?.toString();
        }
      }
    }
    return null;
  }

  // --- HELPERS HIỂN THỊ TRẠNG THÁI HIỆN ĐẠI ---
  String _getStatusLabel(String? status) {
    switch (status) {
      case 'in_progress':
        return 'Đang làm';
      case 'completed':
        return 'Hoàn thành';
      case 'pending':
      default:
        return 'Chờ xử lý';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'in_progress':
        return const Color(0xFF4F46E5);
      case 'completed':
        return const Color(0xFF059669);
      case 'pending':
      default:
        return const Color(0xFFD97706);
    }
  }

  Color _getStatusBgColor(String? status) {
    switch (status) {
      case 'in_progress':
        return const Color(0xFFEEF2FF);
      case 'completed':
        return const Color(0xFFD1FAE5);
      case 'pending':
      default:
        return const Color(0xFFFEF3C7);
    }
  }

  // --- BẢNG THÔNG BÁO HIỆN ĐẠI (BOTTOM SHEET) ---
  void _showNotificationsBottomSheet() {
    final parentContext = context;

    showModalBottomSheet(
      context: parentContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              height: MediaQuery.of(context).size.height * 0.62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Thông báo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                            ),
                          ),
                          if (_unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$_unreadCount mới',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Material(
                        color: _bgColor,
                        borderRadius: BorderRadius.circular(10),
                        child: IconButton(
                          icon: const Icon(Icons.refresh_rounded, color: _primaryColor, size: 22),
                          tooltip: 'Tải lại thông báo',
                          onPressed: () async {
                            await _fetchNotifications();
                            setModalState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: _borderColor),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _notifications.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded,
                              size: 48, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text(
                            'Chưa có thông báo nào',
                            style: TextStyle(color: _textSecondary, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                        : ListView.builder(
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final noti = _notifications[index];
                        final isUnread = noti['isRead'] != true;
                        final date = noti['createdAt'] != null
                            ? noti['createdAt'].toString().substring(0, 10)
                            : '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: isUnread ? const Color(0xFFFFF1F2) : _bgColor,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isUnread ? const Color(0xFFFECDD3) : _borderColor,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: isUnread ? Colors.red.shade100 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.assignment_ind_rounded,
                                    color: isUnread ? Colors.red.shade700 : _textSecondary,
                                    size: 22,
                                  ),
                                  if (isUnread)
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            title: Text(
                              noti['title'] ?? 'Thông báo mới',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                color: _textPrimary,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                noti['message'] ?? '',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _textSecondary,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            trailing: Text(
                              date,
                              style: const TextStyle(color: _textSecondary, fontSize: 11),
                            ),
                            onTap: () async {
                              final notiId = noti['_id']?.toString();
                              final taskId = _extractTaskId(noti);

                              if (notiId != null && isUnread) {
                                await _markAsRead(notiId);
                              }

                              if (modalContext.mounted) {
                                Navigator.pop(modalContext);
                              }

                              if (taskId != null &&
                                  taskId.isNotEmpty &&
                                  parentContext.mounted) {
                                await Navigator.push(
                                  parentContext,
                                  MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(taskId: taskId),
                                  ),
                                );
                                _fetchTasks();
                                _fetchNotifications();
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- LỌC DỮ LIỆU & TÌM KIẾM ---
  List<dynamic> get _filteredTasks {
    return _allTasks.where((task) {
      final title = (task['title'] ?? '').toString().toLowerCase();
      final desc = (task['description'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = title.contains(q) || desc.contains(q);
      final matchesFilter = _filterStatus == 'all' || task['status'] == _filterStatus;
      return matchesSearch && matchesFilter;
    }).toList();
  }

  // --- THỐNG KÊ ---
  Map<String, int> get _statistics {
    int pending = 0;
    int inProgress = 0;
    int completed = 0;

    for (var task in _allTasks) {
      if (task['status'] == 'pending') pending++;
      if (task['status'] == 'in_progress') inProgress++;
      if (task['status'] == 'completed') completed++;
    }

    return {
      'total': _allTasks.length,
      'pending': pending,
      'in_progress': inProgress,
      'completed': completed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final displayTasks = _filteredTasks;
    final stats = _statistics;

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Công việc của tôi',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              '${stats['completed']}/${stats['total']} đã hoàn thành',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          // 1. NÚT CHUÔNG THÔNG BÁO
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: _textPrimary),
                  onPressed: _showNotificationsBottomSheet,
                ),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),

          // 2. ICON NGƯỜI DÙNG (HIỆN EMAIL & NÚT ĐĂNG XUẤT MÀU ĐỎ BÊN DƯỚI)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 52),
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: _borderColor),
              ),
              onSelected: (value) {
                if (value == 'logout') {
                  _handleLogout();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: _primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Đang đăng nhập',
                              style: TextStyle(
                                fontSize: 11,
                                color: _textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(height: 8),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Đăng xuất',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _borderColor),
                ),
                child: const Icon(Icons.person_outline_rounded, color: _textPrimary),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. VÙNG THỐNG KÊ KIÊM BỘ LỌC TRẠNG THÁI (BẤM ĐỂ LỌC)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'Tất cả',
                    count: stats['total']!,
                    color: const Color(0xFF2563EB),
                    icon: Icons.layers_rounded,
                    filterValue: 'all',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    label: 'Chờ xử lý',
                    count: stats['pending']!,
                    color: const Color(0xFFD97706),
                    icon: Icons.schedule_rounded,
                    filterValue: 'pending',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    label: 'Đang làm',
                    count: stats['in_progress']!,
                    color: const Color(0xFF4F46E5),
                    icon: Icons.bolt_rounded,
                    filterValue: 'in_progress',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    label: 'Hoàn thành',
                    count: stats['completed']!,
                    color: const Color(0xFF059669),
                    icon: Icons.check_circle_rounded,
                    filterValue: 'completed',
                  ),
                ),
              ],
            ),
          ),

          // 2. THANH TÌM KIẾM HIỆN ĐẠI
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _borderColor),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: _textPrimary),
                decoration: InputDecoration(
                  hintText: 'Tìm theo tên hoặc mô tả công việc...',
                  hintStyle: const TextStyle(color: _textSecondary, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _textSecondary, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18, color: _textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),

          // 3. DANH SÁCH CÔNG VIỆC
          Expanded(
            child: RefreshIndicator(
              color: _primaryColor,
              onRefresh: _onRefresh,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _primaryColor))
                  : displayTasks.isEmpty
                  ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.14),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.inbox_rounded, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text(
                          'Không có công việc nào',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Nhấn nút "+ Thêm việc" bên dưới để tạo mới',
                          style: TextStyle(fontSize: 13, color: _textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: displayTasks.length,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                itemBuilder: (context, index) {
                  final task = displayTasks[index];
                  final taskId = task['_id'].toString();
                  final status = task['status']?.toString() ?? 'pending';
                  final statusColor = _getStatusColor(status);
                  final statusBgColor = _getStatusBgColor(status);
                  final isCompleted = status == 'completed';

                  final hasUnreadNoti = _notifications.any(
                        (n) => n['isRead'] != true && _extractTaskId(n) == taskId,
                  );

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: hasUnreadNoti ? const Color(0xFFFFFBFB) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: hasUnreadNoti
                                ? Colors.red.shade400
                                : _borderColor,
                            width: hasUnreadNoti ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () async {
                              if (hasUnreadNoti) {
                                await _markTaskNotificationsAsRead(taskId);
                              }

                              if (!mounted) return;
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      TaskDetailScreen(taskId: taskId),
                                ),
                              );
                              _fetchTasks();
                              _fetchNotifications();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: statusColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                task['title'] ?? '',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: isCompleted
                                                      ? _textSecondary
                                                      : _textPrimary,
                                                  decoration: isCompleted
                                                      ? TextDecoration.lineThrough
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            if (hasUnreadNoti) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade50,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Mới',
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        if ((task['description'] ?? '')
                                            .toString()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            task['description'] ?? '',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: _textSecondary,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusBgColor,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            _getStatusLabel(status),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: statusColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _textSecondary,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (hasUnreadNoti)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const TaskCreateScreen()),
          );
          if (result == true) _fetchTasks();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Thêm việc',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
    );
  }

  // --- WIDGET THẺ THỐNG KÊ ---
  Widget _buildStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required String filterValue,
  }) {
    final isSelected = _filterStatus == filterValue;

    return GestureDetector(
      onTap: () => setState(() => _filterStatus = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? color : _borderColor,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 16, color: color),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : _textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}