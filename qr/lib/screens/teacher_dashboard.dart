import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data';

import '../models/student.dart';
import '../screens/qr_generator_screen.dart';
import '../screens/qr_scanner_screen.dart';
import '../screens/attendance_list_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Student> _attendanceList = [];
  final TextEditingController _classNameController = TextEditingController();
  String _currentClass = "Morning Session";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    // Removed sample data - starting with empty list
  }

  void _addAttendance(Student student) {
    setState(() {
      // Check if student already exists for today
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final existingIndex = _attendanceList.indexWhere(
        (s) =>
            s.id == student.id &&
            DateFormat('yyyy-MM-dd').format(s.timestamp) == today,
      );

      if (existingIndex != -1) {
        // Update existing record
        _attendanceList[existingIndex] = student;
      } else {
        // Add new record
        _attendanceList.add(student);
      }
    });
  }

  void _markAsPresent(Student student) {
    _addAttendance(Student(
      id: student.id,
      name: student.name,
      timestamp: DateTime.now(),
      status: AttendanceStatus.present,
    ));
  }

  void _markAsAbsent(String id) {
    setState(() {
      final index = _attendanceList.indexWhere((s) => s.id == id);
      if (index != -1) {
        _attendanceList[index] = Student(
          id: _attendanceList[index].id,
          name: _attendanceList[index].name,
          timestamp: DateTime.now(),
          status: AttendanceStatus.absent,
        );
      }
    });
  }

  Future<void> _exportAttendance() async {
    if (_attendanceList.isEmpty) {
      _showMessage("No attendance data to export", Colors.orange);
      return;
    }

    final csvData = StringBuffer();
    csvData.writeln("ID,Name,Timestamp,Status");

    for (var student in _attendanceList) {
      csvData.writeln(
        "${student.id},${student.name},${student.timestamp},${student.isPresent ? 'Present' : 'Absent'}",
      );
    }

    final bytes = Uint8List.fromList(utf8.encode(csvData.toString()));
    final fileName =
        "attendance_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv";

    await Share.shareXFiles(
      [XFile.fromData(bytes, name: fileName, mimeType: 'text/csv')],
      text:
          "Attendance Report for $_currentClass\nDate: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}",
    );

    _showMessage("Attendance exported successfully", Colors.green);
  }

  void _showAddStudentDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Student Manually"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: "Student ID",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Student Name",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (idController.text.isNotEmpty &&
                  nameController.text.isNotEmpty) {
                _addAttendance(
                  Student(
                    id: idController.text,
                    name: nameController.text,
                    timestamp: DateTime.now(),
                    status: AttendanceStatus.present,
                  ),
                );
                Navigator.pop(context);
                _showMessage("Student added successfully", Colors.green);
              } else {
                _showMessage("Please fill all fields", Colors.orange);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Checker"),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: "Generate"),
            Tab(icon: Icon(Icons.qr_code_scanner), text: "Scan"),
            Tab(icon: Icon(Icons.list), text: "List"),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportAttendance,
            tooltip: "Export Attendance",
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          QRGeneratorScreen(
            onStudentGenerated: (student) {
              _addAttendance(student);
              _tabController.animateTo(2);
              _showMessage("${student.name} marked present!", Colors.green);
            },
          ),
          QRScannerScreen(
            onStudentScanned: (student) {
              _addAttendance(student);
              _tabController.animateTo(2);
              _showMessage("${student.name} marked present!", Colors.green);
            },
          ),
          AttendanceListScreen(
            attendanceList: _attendanceList,
            onMarkPresent: _markAsPresent,
            onMarkAbsent: _markAsAbsent,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddStudentDialog,
        child: const Icon(Icons.add),
        tooltip: "Add Student Manually",
      ),
    );
  }
}
