import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/data_model/reminder_model.dart';
import '../services/notification_service.dart';
import '../utils/reminder_notification_texts.dart';

class ReminderProvider extends ChangeNotifier {
  List<PlantReminder> _reminders = [];
  static const String _reminderKey = 'plant_reminders';

  List<PlantReminder> get reminders => _reminders;
  
  List<PlantReminder> get pendingReminders => 
      _reminders.where((r) => r.isPending).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  
  List<PlantReminder> get todayReminders => 
      _reminders.where((r) => r.isToday).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  
  List<PlantReminder> get upcomingReminders => 
      _reminders.where((r) => r.isUpcoming).toList()..sort((a, b) => a.dateTime.compareTo(b.dateTime));

  ReminderProvider() {
    loadReminders();
  }

  Future<void> loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = prefs.getString(_reminderKey);
      
      if (remindersJson != null) {
        final List<dynamic> decoded = jsonDecode(remindersJson);
        _reminders = decoded.map((json) => PlantReminder.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (e) {
      print('Error loading reminders: $e');
    }
  }

  Future<void> _saveReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final remindersJson = jsonEncode(_reminders.map((r) => r.toJson()).toList());
      await prefs.setString(_reminderKey, remindersJson);
    } catch (e) {
      print('Error saving reminders: $e');
    }
  }

  Future<void> addReminder(PlantReminder reminder) async {
    _reminders.add(reminder);
    await _saveReminders();
    
    // Schedule notification with rotating text
    await NotificationService.scheduleNotification(
      id: reminder.id.hashCode,
      title: 'Plant Follow - ${reminder.taskType}',
      body: ReminderNotificationTexts.getNotificationText(
        reminder.taskType,
        reminder.plantName,
        reminder.id,
      ),
      scheduledDate: reminder.dateTime,
    );
    
    notifyListeners();
  }

  Future<void> deleteReminder(String reminderId) async {
    final reminder = _reminders.firstWhere((r) => r.id == reminderId);
    
    // Cancel notification
    await NotificationService.cancelNotification(reminder.id.hashCode);
    
    _reminders.removeWhere((r) => r.id == reminderId);
    await _saveReminders();
    notifyListeners();
  }

  Future<void> toggleReminderCompletion(String reminderId) async {
    final index = _reminders.indexWhere((r) => r.id == reminderId);
    if (index != -1) {
      _reminders[index] = _reminders[index].copyWith(
        isCompleted: !_reminders[index].isCompleted,
      );
      
      // Cancel notification if completed
      if (_reminders[index].isCompleted) {
        await NotificationService.cancelNotification(_reminders[index].id.hashCode);
      }
      
      await _saveReminders();
      notifyListeners();
    }
  }

  Future<void> updateReminder(PlantReminder updatedReminder) async {
    final index = _reminders.indexWhere((r) => r.id == updatedReminder.id);
    if (index != -1) {
      // Cancel old notification
      await NotificationService.cancelNotification(_reminders[index].id.hashCode);
      
      _reminders[index] = updatedReminder;
      
      // Schedule new notification with rotating text
      if (!updatedReminder.isCompleted) {
        await NotificationService.scheduleNotification(
          id: updatedReminder.id.hashCode,
          title: 'Plant Follow - ${updatedReminder.taskType}',
          body: ReminderNotificationTexts.getNotificationText(
            updatedReminder.taskType,
            updatedReminder.plantName,
            updatedReminder.id,
          ),
          scheduledDate: updatedReminder.dateTime,
        );
      }
      
      await _saveReminders();
      notifyListeners();
    }
  }
}
