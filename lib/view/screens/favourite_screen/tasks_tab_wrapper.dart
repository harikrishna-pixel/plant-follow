import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../provider/reminder_provider.dart';
import '../../../provider/folder_provider.dart';
import '../../../provider/plant_provider.dart';
import '../../../provider/plant_history_provider.dart';
import '../../../model/data_model/reminder_model.dart';
import '../reminder/add_reminder_dialog.dart';

// Wrapper for Tasks tab without AppBar
class TasksTab extends StatefulWidget {
  const TasksTab({super.key});

  @override
  State<TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<TasksTab> {
  bool _vacationMode = false;

  String _getDisplayTaskType(String taskType) {
    // Remove "PlantFollow: " prefix if present (for display only)
    return taskType.replaceFirst('PlantFollow: ', '');
  }

  String _resolveTaskCategory(String taskType) {
    final normalized = taskType.toLowerCase();
    if (normalized.contains('water')) return 'watering';
    if (normalized.contains('fertil')) return 'fertilizing';
    if (normalized.contains('soil')) return 'soil';
    if (normalized.contains('trim') || normalized.contains('cut')) return 'trimming';
    if (normalized.contains('repot')) return 'repotting';
    if (normalized.contains('pest')) return 'pest';
    if (normalized.contains('prun')) return 'pruning';
    if (normalized.contains('mist')) return 'misting';
    return 'default';
  }

  Color _getTaskColor(String taskType) {
    switch (_resolveTaskCategory(taskType)) {
      case 'watering':
        return const Color(0xFF2196F3);
      case 'fertilizing':
        return const Color(0xFF4CAF50);
      case 'soil':
        return const Color(0xFF795548);
      case 'trimming':
        return const Color(0xFFFF5722);
      case 'repotting':
        return const Color(0xFF9C27B0);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  IconData _getTaskIcon(String taskType) {
    switch (_resolveTaskCategory(taskType)) {
      case 'watering':
        return Icons.water_drop;
      case 'fertilizing':
        return Icons.eco;
      case 'soil':
        return Icons.terrain;
      case 'trimming':
        return Icons.content_cut;
      case 'repotting':
        return Icons.move_up;
      case 'misting':
        return Icons.water;
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      body: Consumer2<ReminderProvider, FolderProvider>(
        builder: (context, reminderProvider, folderProvider, child) {
          // Get all reminders
          final allReminders = [
            ...reminderProvider.pendingReminders,
            ...reminderProvider.todayReminders,
            ...reminderProvider.upcomingReminders,
          ];

          return Column(
            children: [
              SizedBox(height: 15.h,),
              // Add Task Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showAddTaskDialog(context, folderProvider),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.add, color: Colors.white, size: 18),
                      label: Text(
                        'Add Task',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tasks List
              Expanded(
                child: allReminders.isEmpty
                    ? _buildEmptyState()
                    : _buildReminderList(allReminders, 'all'),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.task_alt,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No tasks yet',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add tasks for your garden plants',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context, FolderProvider folderProvider) {
    // Get all plants from folders
    final allPlantIds = <String>{};
    for (var folder in folderProvider.folders) {
      allPlantIds.addAll(folder.plantIds);
    }
    
    if (allPlantIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No plants in your garden. Add plants first.',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Show dialog to select plant and add task
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddReminderDialog(),
    );
  }

  Widget _buildReminderList(List<PlantReminder> reminders, String type) {
    if (reminders.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 120),
        physics: const BouncingScrollPhysics(),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                type == 'today'
                    ? Icons.event_available
                    : Icons.notifications_none,
                size: 80,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'You have no task',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 30),
              Text(
                'Stay on track with quick plant care ideas below.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          // const SizedBox(height: 32),
          // Text(
          //   'Suggested plant care tasks',
          //   style: GoogleFonts.poppins(
          //     fontSize: 16,
          //     fontWeight: FontWeight.w600,
          //     color: const Color(0xFF2E7D32),
          //   ),
          // ),
          // const SizedBox(height: 12),
          // for (final task in _defaultTaskSuggestions) ...[
          //   _buildSuggestionCard(task),
          //   const SizedBox(height: 12),
          // ],
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: reminders.length,
      itemBuilder: (context, index) {
        final reminder = reminders[index];
        return _buildReminderCard(reminder);
      },
    );
  }

  Widget _buildReminderCard(PlantReminder reminder) {
    final taskColor = _getTaskColor(reminder.taskType);
    final taskIcon = _getTaskIcon(reminder.taskType);

    return Consumer<PlantProvider>(
      builder: (context, plantProvider, child) {
        // Find plant image from favorites by name
        String? plantImagePath;
        try {
          final plant = plantProvider.favorites.firstWhere(
            (p) => p.name == reminder.plantName,
          );
          plantImagePath = plant.imagePath;
        } catch (e) {
          plantImagePath = null;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plant Image or Task Icon
                if (plantImagePath != null && plantImagePath!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: plantImagePath!.startsWith('http')
                        ? Image.network(
                            plantImagePath!,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: taskColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(taskIcon, color: taskColor, size: 28),
                              );
                            },
                          )
                        : File(plantImagePath!).existsSync()
                            ? Image.file(
                                File(plantImagePath!),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 60,
                                    height: 60,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: taskColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(taskIcon, color: taskColor, size: 28),
                                  );
                                },
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: taskColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(taskIcon, color: taskColor, size: 28),
                              ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: taskColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(taskIcon, color: taskColor, size: 28),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reminder.plantName,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getDisplayTaskType(reminder.taskType),
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMM dd, yyyy • hh:mm a').format(reminder.createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Delete Icon
                InkWell(
                  onTap: () {
                    _showDeleteConfirmation(context, reminder);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.delete_outline,
                      color: Color(0xFFF44336),
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, PlantReminder reminder) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Reminder?',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFF44336),
          ),
        ),
        content: Text(
          'Are you sure you want to delete this reminder?',
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final provider = Provider.of<ReminderProvider>(context, listen: false);
              provider.deleteReminder(reminder.id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reminder deleted', style: GoogleFonts.poppins()),
                  backgroundColor: const Color(0xFFF44336),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF44336),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Delete', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, String> task) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF4CAF50).withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.spa,
              color: Color(0xFF2E7D32),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] ?? '',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  task['subtitle'] ?? '',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

