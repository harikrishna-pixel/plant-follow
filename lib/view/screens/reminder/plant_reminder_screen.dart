import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../provider/reminder_provider.dart';
import '../../../model/data_model/reminder_model.dart';
import '../../../widgets/banner_widget.dart';
import 'add_reminder_dialog.dart';

class PlantReminderScreen extends StatefulWidget {
  const PlantReminderScreen({super.key});

  @override
  State<PlantReminderScreen> createState() => _PlantReminderScreenState();
}

class _PlantReminderScreenState extends State<PlantReminderScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
      default:
        return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FDF8),
      appBar: AppBar(
        title: Text(
          'Plant Reminders',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2E7D32),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF4CAF50),
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: const Color(0xFF4CAF50),
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Today'),
            Tab(text: 'Upcoming'),
          ],
        ),
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // Banner Widget
              const BannerWidget(screenId: 'reminder'),
              // TabBarView
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReminderList(provider.pendingReminders, 'pending'),
                    _buildReminderList(provider.todayReminders, 'today'),
                    _buildReminderList(provider.upcomingReminders, 'upcoming'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const AddReminderDialog(),
          );
        },
        backgroundColor: const Color(0xFF4CAF50),
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          'Add Reminder',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderList(List<PlantReminder> reminders, String type) {
    if (reminders.isEmpty) {
      return Center(
        child: Column(
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
              type == 'today'
                  ? 'No reminders for today'
                  : type == 'upcoming'
                      ? 'No upcoming reminders'
                      : 'No pending reminders',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add a reminder to keep track of plant care',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
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
    final provider = Provider.of<ReminderProvider>(context, listen: false);

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
            // Leading Icon
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: taskColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(taskIcon, color: taskColor, size: 28),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.plantName,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getDisplayTaskType(reminder.taskType),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: taskColor,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          DateFormat('MMM dd, yyyy • hh:mm a').format(reminder.dateTime),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action Buttons
            Column(
              children: [
                InkWell(
                  onTap: () {
                    provider.toggleReminderCompletion(reminder.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          reminder.isCompleted
                              ? 'Reminder marked as incomplete'
                              : 'Reminder completed!',
                          style: GoogleFonts.poppins(),
                        ),
                        backgroundColor: const Color(0xFF4CAF50),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      reminder.isCompleted
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                      color: reminder.isCompleted
                          ? const Color(0xFF4CAF50)
                          : Colors.grey[400],
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
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
          ],
        ),
      ),
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
}
