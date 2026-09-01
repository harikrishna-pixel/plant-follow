/// Plant-linked care interval. Complements date-based [PlantReminder]s.
/// Always keyed by durable [plantId], never by name alone.
class CareRule {
  final String id;
  final String plantId;
  final String careType;
  final int baseIntervalDays;
  final DateTime? lastCompletedAt;
  final DateTime nextDueAt;
  final bool enabled;
  /// Existing reminder used for notifications. Avoids a second schedule.
  final String? reminderId;
  final Map<String, dynamic> metadata;

  CareRule({
    required this.id,
    required this.plantId,
    required this.careType,
    required this.baseIntervalDays,
    this.lastCompletedAt,
    required this.nextDueAt,
    this.enabled = true,
    this.reminderId,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plantId': plantId,
      'careType': careType,
      'baseIntervalDays': baseIntervalDays,
      'lastCompletedAt': lastCompletedAt?.toIso8601String(),
      'nextDueAt': nextDueAt.toIso8601String(),
      'enabled': enabled,
      'reminderId': reminderId,
      'metadata': metadata,
    };
  }

  factory CareRule.fromJson(Map<String, dynamic> json) {
    return CareRule(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      careType: json['careType'] as String? ?? 'Watering',
      baseIntervalDays: (json['baseIntervalDays'] as num?)?.toInt() ?? 7,
      lastCompletedAt: json['lastCompletedAt'] is String
          ? DateTime.parse(json['lastCompletedAt'] as String)
          : null,
      nextDueAt: DateTime.parse(json['nextDueAt'] as String),
      enabled: json['enabled'] as bool? ?? true,
      reminderId: json['reminderId'] as String?,
      metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? {}),
    );
  }

  CareRule copyWith({
    String? id,
    String? plantId,
    String? careType,
    int? baseIntervalDays,
    DateTime? lastCompletedAt,
    DateTime? nextDueAt,
    bool? enabled,
    String? reminderId,
    Map<String, dynamic>? metadata,
  }) {
    return CareRule(
      id: id ?? this.id,
      plantId: plantId ?? this.plantId,
      careType: careType ?? this.careType,
      baseIntervalDays: baseIntervalDays ?? this.baseIntervalDays,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      enabled: enabled ?? this.enabled,
      reminderId: reminderId ?? this.reminderId,
      metadata: metadata ?? this.metadata,
    );
  }
}
