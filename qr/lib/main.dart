import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:gal/gal.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Attendance Checker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const TeacherDashboard(),
    );
  }
}

// Models
class Student {
  final String id;
  final String name;
  final DateTime timestamp;
  final AttendanceStatus status;

  Student({
    required this.id,
    required this.name,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'timestamp': timestamp.toIso8601String(),
    'status': status.index,
  };

  factory Student.fromJson(Map<String, dynamic> json) => Student(
    id: json['id'],
    name: json['name'],
    timestamp: DateTime.parse(json['timestamp']),
    status: AttendanceStatus.values[json['status']],
  );
}

enum AttendanceStatus { present, absent }

// Teacher Dashboard
class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Student> _attendanceList = [];
  String _currentClass = "Morning Session";
  final TextEditingController _classNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAttendanceData();
  }

  Future<void> _loadAttendanceData() async {
    // Load from shared preferences or local storage
    // For demo, we'll use sample data
    setState(() {
      _attendanceList = [
        Student(
          id: "2024001",
          name: "John Doe",
          timestamp: DateTime.now(),
          status: AttendanceStatus.present,
        ),
        Student(
          id: "2024002",
          name: "Jane Smith",
          timestamp: DateTime.now(),
          status: AttendanceStatus.absent,
        ),
      ];
    });
  }

  void _addAttendance(Student student) {
    setState(() {
      // Check if student already exists for today
      final existingIndex = _attendanceList.indexWhere(
        (s) =>
            s.id == student.id &&
            DateFormat('yyyy-MM-dd').format(s.timestamp) ==
                DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );

      if (existingIndex != -1) {
        _attendanceList[existingIndex] = student;
      } else {
        _attendanceList.add(student);
      }
    });
  }

  Future<void> _exportAttendance() async {
    final csvData = StringBuffer();
    csvData.writeln("ID,Name,Timestamp,Status");

    for (var student in _attendanceList) {
      csvData.writeln(
        "${student.id},${student.name},${student.timestamp},${student.status == AttendanceStatus.present ? 'Present' : 'Absent'}",
      );
    }

    final bytes = Uint8List.fromList(utf8.encode(csvData.toString()));
    final fileName =
        "attendance_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.csv";

    await Share.shareXFiles([
      XFile.fromData(bytes, name: fileName, mimeType: 'text/csv'),
    ], text: "Attendance Report for $_currentClass");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Teacher Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.qr_code), text: "Generate QR"),
            Tab(icon: Icon(Icons.qr_code_scanner), text: "Scan QR"),
            Tab(icon: Icon(Icons.list), text: "Attendance List"),
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
            },
          ),
          QRScannerScreen(onStudentScanned: _addAttendance),
          AttendanceListScreen(
            attendanceList: _attendanceList,
            onMarkAbsent: (id) {
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
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddStudentDialog();
        },
        child: const Icon(Icons.add),
        tooltip: "Manually Add Student",
      ),
    );
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
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Student Name",
                border: OutlineInputBorder(),
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
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _classNameController.dispose();
    super.dispose();
  }
}

// QR Generator Screen
class QRGeneratorScreen extends StatefulWidget {
  final Function(Student) onStudentGenerated;

  const QRGeneratorScreen({super.key, required this.onStudentGenerated});

  @override
  State<QRGeneratorScreen> createState() => _QRGeneratorScreenState();
}

class _QRGeneratorScreenState extends State<QRGeneratorScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey _qrKey = GlobalKey();
  String _qrData = "";
  bool _isSaving = false;

  void _generateData() {
    if (_idController.text.isNotEmpty && _nameController.text.isNotEmpty) {
      Map<String, String> dataMap = {
        "id": _idController.text,
        "name": _nameController.text,
        "timestamp": DateTime.now().toIso8601String(),
      };
      setState(() {
        _qrData = jsonEncode(dataMap);
      });
    } else {
      setState(() {
        _qrData = "";
      });
    }
  }

  Future<bool> _requestPermission() async {
    if (await Permission.photos.isGranted) return true;
    final photos = await Permission.photos.request();
    return photos.isGranted;
  }

  Future<void> _saveQrToGallery() async {
    setState(() => _isSaving = true);

    try {
      bool hasPermission = await _requestPermission();
      if (!hasPermission) {
        _showMessage("Permission denied", Colors.red);
        return;
      }

      RenderRepaintBoundary? boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        _showMessage("Error capturing QR", Colors.red);
        return;
      }

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        _showMessage("Error generating image", Colors.red);
        return;
      }

      Uint8List pngBytes = byteData.buffer.asUint8List();
      final fileName =
          "qr_${_idController.text}_${DateTime.now().millisecondsSinceEpoch}.png";

      await Gal.putImageBytes(pngBytes, name: fileName);
      _showMessage("Saved to gallery ✅", Colors.green);
    } catch (e) {
      _showMessage("Error: $e", Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _markAttendance() {
    if (_idController.text.isNotEmpty && _nameController.text.isNotEmpty) {
      widget.onStudentGenerated(
        Student(
          id: _idController.text,
          name: _nameController.text,
          timestamp: DateTime.now(),
          status: AttendanceStatus.present,
        ),
      );
      _showMessage("Attendance marked successfully!", Colors.green);
      _idController.clear();
      _nameController.clear();
      setState(() {
        _qrData = "";
      });
    } else {
      _showMessage("Please enter student details", Colors.orange);
    }
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _idController,
                    decoration: const InputDecoration(
                      labelText: "Student ID",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    onChanged: (_) => _generateData(),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Student Name",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    onChanged: (_) => _generateData(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (_qrData.isNotEmpty) ...[
            Center(
              child: RepaintBoundary(
                key: _qrKey,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        spreadRadius: 2,
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(16),
                  child: QrImageView(
                    data: _qrData,
                    size: 250,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.blue,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _saveQrToGallery,
                    icon: const Icon(Icons.download),
                    label: Text(_isSaving ? "Saving..." : "Save QR"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _markAttendance,
                    icon: const Icon(Icons.check_circle),
                    label: const Text("Mark Present"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.qr_code, size: 80, color: Colors.grey),
                  SizedBox(height: 10),
                  Text(
                    "Enter student details to generate QR code",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// QR Scanner Screen
class QRScannerScreen extends StatefulWidget {
  final Function(Student) onStudentScanned;

  const QRScannerScreen({super.key, required this.onStudentScanned});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isScanning = true;
  String lastScannedId = "";

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!isScanning) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? scannedData = barcode.rawValue;
      if (scannedData != null && scannedData != lastScannedId) {
        try {
          final Map<String, dynamic> data = jsonDecode(scannedData);
          final student = Student(
            id: data['id'],
            name: data['name'],
            timestamp: DateTime.parse(data['timestamp']),
            status: AttendanceStatus.present,
          );

          setState(() {
            isScanning = false;
            lastScannedId = scannedData;
          });

          widget.onStudentScanned(student);
          _showDialog(student);
        } catch (e) {
          _showMessage("Invalid QR Code", Colors.red);
        }
        break;
      }
    }
  }

  void _showDialog(Student student) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Attendance Marked"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Student: ${student.name}"),
            Text("ID: ${student.id}"),
            const SizedBox(height: 10),
            const Text(
              "✓ Marked as Present",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                isScanning = true;
                lastScannedId = "";
              });
            },
            child: const Text("Scan Next"),
          ),
        ],
      ),
    );
  }

  void _showMessage(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: MobileScanner(
            controller: cameraController,
            onDetect: _onDetect,
          ),
        ),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                "Scan QR Code",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Position the QR code within the frame",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      cameraController.torchState == TorchState.off
                          ? Icons.flashlight_off
                          : Icons.flashlight_on,
                    ),
                    onPressed: () => cameraController.toggleTorch(),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.switch_camera),
                    onPressed: () => cameraController.switchCamera(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Attendance List Screen
class AttendanceListScreen extends StatelessWidget {
  final List<Student> attendanceList;
  final Function(String) onMarkAbsent;

  const AttendanceListScreen({
    super.key,
    required this.attendanceList,
    required this.onMarkAbsent,
  });

  @override
  Widget build(BuildContext context) {
    final presentCount = attendanceList
        .where((s) => s.status == AttendanceStatus.present)
        .length;
    final absentCount = attendanceList.length - presentCount;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard("Present", presentCount, Colors.green),
              _buildStatCard("Absent", absentCount, Colors.red),
              _buildStatCard("Total", attendanceList.length, Colors.blue),
            ],
          ),
        ),
        Expanded(
          child: attendanceList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 80, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "No students marked yet",
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Scan QR codes or add manually",
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: attendanceList.length,
                  itemBuilder: (context, index) {
                    final student = attendanceList[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              student.status == AttendanceStatus.present
                              ? Colors.green
                              : Colors.red,
                          child: Text(
                            student.name[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          student.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("ID: ${student.id}"),
                            Text(
                              DateFormat('hh:mm a').format(student.timestamp),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        trailing: student.status == AttendanceStatus.present
                            ? const Chip(
                                label: Text("Present"),
                                backgroundColor: Colors.green,
                                labelStyle: TextStyle(color: Colors.white),
                              )
                            : IconButton(
                                icon: const Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.green,
                                ),
                                onPressed: () => onMarkAbsent(student.id),
                                tooltip: "Mark Present",
                              ),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
