/// Append-only plant event types for the PlantFollow event log.
/// Only the foundation is used in Phase 1; later phases write these events.
enum PlantEventType {
  identification,
  diagnosis,
  treatment,
  careCompletion,
  recoveryCheckIn,
  plantPhoto,
  outcome,
  milestone,
  harvest,
}

extension PlantEventTypeCodec on PlantEventType {
  String get wireName {
    switch (this) {
      case PlantEventType.identification:
        return 'identification';
      case PlantEventType.diagnosis:
        return 'diagnosis';
      case PlantEventType.treatment:
        return 'treatment';
      case PlantEventType.careCompletion:
        return 'care_completion';
      case PlantEventType.recoveryCheckIn:
        return 'recovery_check_in';
      case PlantEventType.plantPhoto:
        return 'plant_photo';
      case PlantEventType.outcome:
        return 'outcome';
      case PlantEventType.milestone:
        return 'milestone';
      case PlantEventType.harvest:
        return 'harvest';
    }
  }

  static PlantEventType fromWire(String value) {
    switch (value) {
      case 'identification':
        return PlantEventType.identification;
      case 'diagnosis':
        return PlantEventType.diagnosis;
      case 'treatment':
        return PlantEventType.treatment;
      case 'care_completion':
        return PlantEventType.careCompletion;
      case 'recovery_check_in':
        return PlantEventType.recoveryCheckIn;
      case 'plant_photo':
        return PlantEventType.plantPhoto;
      case 'outcome':
        return PlantEventType.outcome;
      case 'milestone':
        return PlantEventType.milestone;
      case 'harvest':
        return PlantEventType.harvest;
      default:
        throw FormatException('Unknown plant event type: $value');
    }
  }

  /// Unknown/future wire names skip rather than crash the timeline.
  static PlantEventType? tryFromWire(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return fromWire(value);
    } on FormatException {
      return null;
    }
  }
}

/// One append-only record in a plant's event log.
class PlantEvent {
  final String id;
  final String plantId;
  final PlantEventType eventType;
  final DateTime timestamp;
  final Map<String, dynamic> payload;
  final String source;

  PlantEvent({
    required this.id,
    required this.plantId,
    required this.eventType,
    required this.timestamp,
    Map<String, dynamic>? payload,
    this.source = 'app',
  }) : payload = payload ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plantId': plantId,
      'eventType': eventType.wireName,
      'timestamp': timestamp.toIso8601String(),
      'payload': payload,
      'source': source,
    };
  }

  factory PlantEvent.fromJson(Map<String, dynamic> json) {
    final event = tryFromJson(json);
    if (event == null) {
      throw FormatException('Unknown or invalid plant event');
    }
    return event;
  }

  /// Unknown/future event types return null instead of throwing.
  static PlantEvent? tryFromJson(Map<String, dynamic> json) {
    try {
      final type = PlantEventTypeCodec.tryFromWire(
        json['eventType'] as String?,
      );
      if (type == null) return null;
      final id = json['id'];
      final plantId = json['plantId'];
      final timestamp = json['timestamp'];
      if (id is! String || plantId is! String || timestamp is! String) {
        return null;
      }
      return PlantEvent(
        id: id,
        plantId: plantId,
        eventType: type,
        timestamp: DateTime.parse(timestamp),
        payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
        source: json['source'] as String? ?? 'app',
      );
    } catch (_) {
      return null;
    }
  }
}
