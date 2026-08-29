class PlantReminder {
  final String id;
  final String plantName;
  final String taskType;
  final DateTime dateTime;
  final bool isCompleted;
  final DateTime createdAt;

  PlantReminder({
    required this.id,
    required this.plantName,
    required this.taskType,
    required this.dateTime,
    this.isCompleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plantName': plantName,
      'taskType': taskType,
      'dateTime': dateTime.toIso8601String(),
      'isCompleted': isCompleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PlantReminder.fromJson(Map<String, dynamic> json) {
    return PlantReminder(
      id: json['id'] as String,
      plantName: json['plantName'] as String,
      taskType: json['taskType'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      isCompleted: json['isCompleted'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  PlantReminder copyWith({
    String? id,
    String? plantName,
    String? taskType,
    DateTime? dateTime,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return PlantReminder(
      id: id ?? this.id,
      plantName: plantName ?? this.plantName,
      taskType: taskType ?? this.taskType,
      dateTime: dateTime ?? this.dateTime,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isPending => !isCompleted && dateTime.isAfter(DateTime.now());
  bool get isToday {
    final now = DateTime.now();
    return !isCompleted &&
        dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }
  bool get isUpcoming => !isCompleted && dateTime.isAfter(DateTime.now().add(const Duration(days: 1)));
}
