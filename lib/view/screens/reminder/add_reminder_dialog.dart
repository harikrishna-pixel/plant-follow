import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../provider/reminder_provider.dart';
import '../../../provider/plant_provider.dart';
import '../../../provider/folder_provider.dart';
import '../../../model/data_model/reminder_model.dart';

class AddReminderDialog extends StatefulWidget {
  final String? initialPlantName;
  
  const AddReminderDialog({super.key, this.initialPlantName});

  @override
  State<AddReminderDialog> createState() => _AddReminderDialogState();
}

class _AddReminderDialogState extends State<AddReminderDialog> {
  final _plantNameController = TextEditingController();
  String? _selectedPlantName;
  String? _selectedTaskType;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final List<String> _taskTypes = [
    'Watering💧',
    'Fertilizing🌿',
    'Soil Check🌱',
    'Trimming✂️',
    'Repotting🏡',
    'Pest Control🐞',
    'Pruning🍃',
    'Misting💦',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPlantName != null) {
      _selectedPlantName = widget.initialPlantName;
      _plantNameController.text = widget.initialPlantName!;
    }
  }

  @override
  void dispose() {
    _plantNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF4CAF50),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _checkNotificationPermission() async {
    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
    final iosImplementation = notifications.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    
    // Check current permission status
    final status = await Permission.notification.status;
    print('🔔 Current notification status: $status');
    print('   isGranted: ${status.isGranted}');
    print('   isPermanentlyDenied: ${status.isPermanentlyDenied}');
    print('   isDenied: ${status.isDenied}');
    
    bool? permissionGranted;
    bool shouldShowSettingsMessage = false;
    
    if (status.isGranted || status.isLimited) {
      // Already granted - save directly
      print('✅ Permission already granted - saving directly');
      permissionGranted = true;
      await _proceedToSaveReminder(showSettingsMessage: false);
      return;
    }
    
    // Check if permanently denied (user previously said no)
    if (status.isPermanentlyDenied) {
      // iOS won't show dialog again - user must go to Settings
      print('⚠️ Permission permanently denied - directing to Settings');
      shouldShowSettingsMessage = true;
    } else {
      // Permission not yet requested OR previously denied
      // Try to request - iOS will show dialog only if never asked before
      print('📱 Requesting iOS native permission...');
      permissionGranted = await iosImplementation?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      print('🔔 iOS permission dialog result: $permissionGranted');
      
      // If permission NOT granted, show Settings message
      if (permissionGranted != true) {
        print('⚠️ Permission not granted - showing Settings message');
        shouldShowSettingsMessage = true;
      }
    }
    
    // Save the reminder and pass whether to show settings message
    await _proceedToSaveReminder(showSettingsMessage: shouldShowSettingsMessage);
  }

  Future<void> _proceedToSaveReminder({required bool showSettingsMessage}) async {
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // Strip "PlantFollow: " prefix if present (for backward compatibility)
    String taskType = _selectedTaskType!.replaceFirst('PlantFollow: ', '');
    
    final reminder = PlantReminder(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      plantName: _selectedPlantName ?? _plantNameController.text.trim(),
      taskType: taskType,
      dateTime: dateTime,
      createdAt: DateTime.now(),
    );

    final provider = Provider.of<ReminderProvider>(context, listen: false);
    
    // Wait for reminder to be added and notification to be scheduled
    await provider.addReminder(reminder);
    print('✅ Reminder added and notification scheduled successfully');

    // Get the navigator and scaffold messenger before popping
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    // Pop the dialog
    navigator.pop();

    // Show success message
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Reminder created!', style: GoogleFonts.poppins()),
          ],
        ),
        backgroundColor: const Color(0xFF4CAF50),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );

    // If we need to show settings message, schedule it after success message
    if (showSettingsMessage) {
      print('🟠 Scheduling settings message to show after success snackbar');
      Future.delayed(const Duration(milliseconds: 2500), () {
        print('🟠 Showing orange settings snackbar NOW');
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Enable notifications in Settings to receive reminders',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFF9800),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
        print('🟠 Orange snackbar shown successfully');
      });
    }
  }

  void _saveReminder() {
    if (_plantNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter plant name', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFF44336),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_selectedTaskType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a task type', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFF44336),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select date and time', style: GoogleFonts.poppins()),
          backgroundColor: const Color(0xFFF44336),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    // Check notification permission before saving
    _checkNotificationPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Plant Name - Dropdown from Garden
            Text(
              'Select Plant from Garden',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Consumer2<PlantProvider, FolderProvider>(
              builder: (context, plantProvider, folderProvider, child) {
                // Get all plants from all folders
                final allPlantIds = <String>{};
                for (var folder in folderProvider.folders) {
                  allPlantIds.addAll(folder.plantIds);
                }
                
                // Get actual plant objects from favorites
                final gardenPlants = plantProvider.favorites.where((plant) {
                  return allPlantIds.contains(plant.uniqueId);
                }).toList();
                
                // If no plants in garden, show text field
                if (gardenPlants.isEmpty) {
                  return TextField(
                    controller: _plantNameController,
                    decoration: InputDecoration(
                      hintText: 'Enter plant name',
                      hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: GoogleFonts.inter(),
                    onChanged: (value) {
                      setState(() {
                        _selectedPlantName = value;
                        _plantNameController.text = value;
                      });
                    },
                  );
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedPlantName ?? (widget.initialPlantName ?? gardenPlants.first.name),
                      isExpanded: true,
                      hint: Text(
                        'Select a plant',
                        style: GoogleFonts.inter(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      items: gardenPlants.map((plant) {
                        return DropdownMenuItem<String>(
                          value: plant.name,
                          child: Row(
                            children: [
                              if (plant.imagePath != null && plant.imagePath!.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: plant.imagePath!.startsWith('http')
                                      ? Image.network(
                                          plant.imagePath!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E8),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.local_florist,
                                                color: Color(0xFF4CAF50),
                                                size: 20,
                                              ),
                                            );
                                          },
                                        )
                                      : File(plant.imagePath!).existsSync()
                                          ? Image.file(
                                              File(plant.imagePath!),
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE8F5E8),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.local_florist,
                                                    color: Color(0xFF4CAF50),
                                                    size: 20,
                                                  ),
                                                );
                                              },
                                            )
                                          : Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F5E8),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.local_florist,
                                                color: Color(0xFF4CAF50),
                                                size: 20,
                                              ),
                                            ),
                                )
                              else
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E8),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.local_florist,
                                    color: Color(0xFF4CAF50),
                                    size: 20,
                                  ),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  plant.name,
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[800],
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPlantName = value;
                          _plantNameController.text = value ?? '';
                        });
                      },
                      style: GoogleFonts.inter(
                        color: Colors.grey[800],
                        fontSize: 14,
                      ),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Task Type
            Text(
              'Task Type',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTaskType,
                  hint: Text(
                    'Select task type',
                    style: GoogleFonts.inter(color: Colors.grey[400]),
                  ),
                  isExpanded: true,
                  icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF4CAF50)),
                  style: GoogleFonts.inter(color: Colors.black),
                  items: _taskTypes.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() => _selectedTaskType = newValue);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Date & Time
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, 
                                  size: 18, color: Color(0xFF4CAF50)),
                              const SizedBox(width: 8),
                              Text(
                                _selectedDate != null
                                    ? DateFormat('MMM dd, yyyy').format(_selectedDate!)
                                    : 'Select date',
                                style: GoogleFonts.inter(
                                  color: _selectedDate != null
                                      ? Colors.black
                                      : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Time',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _selectTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.access_time, 
                                  size: 18, color: Color(0xFF4CAF50)),
                              const SizedBox(width: 8),
                              Text(
                                _selectedTime != null
                                    ? _selectedTime!.format(context)
                                    : 'Select time',
                                style: GoogleFonts.inter(
                                  color: _selectedTime != null
                                      ? Colors.black
                                      : Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveReminder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Save Reminder',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}