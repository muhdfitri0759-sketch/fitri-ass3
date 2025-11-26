import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'logout.dart';

class SmartRoomDashboard extends StatefulWidget {
  const SmartRoomDashboard({super.key});

  @override
  State<SmartRoomDashboard> createState() => _SmartRoomDashboardState();
}

class _SmartRoomDashboardState extends State<SmartRoomDashboard> {
  final DatabaseReference sensorRef =
      FirebaseDatabase.instance.ref("Sensor");
  final DatabaseReference actuatorRef =
      FirebaseDatabase.instance.ref("Actuator");


  double temperature = 0.0;
  double humidity = 0.0;
  double distance = 0.0;
  int gasLevel = 0;


  String currentMode = "auto";
  int buzzerStatus = 0;
  int ledStatus = 0;

  bool isLoading = true;


  StreamSubscription<DatabaseEvent>? _sensorSubscription;
  StreamSubscription<DatabaseEvent>? _actuatorSubscription;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {

    _sensorSubscription?.cancel();
    _actuatorSubscription?.cancel();
    super.dispose();
  }


  void _setupListeners() {

    _sensorSubscription = sensorRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map && mounted) {
        setState(() {
          temperature = (data['temperature'] ?? 0.0).toDouble();
          humidity = (data['humidity'] ?? 0.0).toDouble();
          distance = (data['distance'] ?? 0.0).toDouble();
          gasLevel = (data['gas_level'] ?? 0).toInt();
          isLoading = false;
        });
      }
    });


    _actuatorSubscription = actuatorRef.onValue.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map && mounted) {
        setState(() {
          currentMode = (data['mode'] ?? "auto").toString().toLowerCase();
          buzzerStatus = (data['buzzer_status'] ?? 0).toInt();
          ledStatus = (data['led_status'] ?? 0).toInt();
        });
      }
    });
  }

  void _toggleMode() {
    String newMode = currentMode == "auto" ? "manual" : "auto";
    actuatorRef.update({"mode": newMode});
  }

  void _toggleBuzzer() {
    int newStatus = buzzerStatus == 1 ? 0 : 1;
    actuatorRef.update({"buzzer_status": newStatus});
  }

  void _toggleLED() {
    int newStatus = ledStatus == 1 ? 0 : 1;
    actuatorRef.update({"led_status": newStatus});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Smart Room Dashboard"),
        backgroundColor: Colors.lightGreen[800],
        elevation: 0,
        actions: const [
          LogoutButton(),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  isLoading = true;
                });
                await Future.delayed(const Duration(seconds: 1));
                setState(() {
                  isLoading = false;
                });
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    _buildModeCard(),
                    const SizedBox(height: 16),


                    _buildSensorCards(),
                    const SizedBox(height: 16),


                    if (currentMode == "manual") ...[
                      _buildActuatorControls(),
                      const SizedBox(height: 16),
                    ],


                    _buildStatusInfo(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildModeCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Control Mode",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Switch(
                  value: currentMode == "auto",
                  onChanged: (_) => _toggleMode(),
                  activeColor: Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: currentMode == "auto"
                    ? Colors.green.withOpacity(0.2)
                    : Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                currentMode == "auto" ? "🔄 AUTO MODE" : "👤 MANUAL MODE",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: currentMode == "auto" ? Colors.green[800] : Colors.orange[800],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentMode == "auto"
                  ? "System controls devices automatically based on sensors"
                  : "You can manually control buzzer and LED",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorCards() {
    return Column(
      children: [
        const Text(
          "Sensor Data",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                "🌡️ Temperature",
                "${temperature.toStringAsFixed(1)}°C",
                temperature > 30 ? Colors.red : Colors.blue,
                Icons.thermostat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                "💧 Humidity",
                "${humidity.toStringAsFixed(1)}%",
                Colors.cyan,
                Icons.water_drop,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSensorCard(
                "📏 Distance",
                "${distance.toStringAsFixed(1)} cm",
                distance < 10 ? Colors.red : Colors.green,
                Icons.straighten,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSensorCard(
                "💨 Gas Level",
                "$gasLevel",
                gasLevel > 500 ? Colors.red : Colors.green,
                Icons.air,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorCard(
      String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActuatorControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Manual Control",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActuatorCard(
                "🔔 Buzzer",
                buzzerStatus == 1 ? "ON" : "OFF",
                buzzerStatus == 1 ? Colors.red : Colors.grey,
                _toggleBuzzer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActuatorCard(
                "💡 LED",
                ledStatus == 1 ? "ON" : "OFF",
                ledStatus == 1 ? Colors.amber : Colors.grey,
                _toggleLED,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActuatorCard(
      String title, String status, Color color, VoidCallback onTap) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tap to toggle",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusInfo() {
    return Card(
      elevation: 2,
      color: Colors.grey[100],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "System Status",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildStatusRow("Buzzer", buzzerStatus == 1 ? "ON" : "OFF",
                buzzerStatus == 1 ? Colors.red : Colors.grey),
            _buildStatusRow("LED", ledStatus == 1 ? "ON" : "OFF",
                ledStatus == 1 ? Colors.amber : Colors.grey),
            if (currentMode == "auto") ...[
              _buildStatusRow("Auto Logic", "Active", Colors.green),
              if (distance < 10)
                _buildStatusRow("⚠️ Warning", "Object too close!", Colors.red),
              if (gasLevel > 500)
                _buildStatusRow("⚠️ Warning", "Gas level high!", Colors.red),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

