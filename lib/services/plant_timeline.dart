import '../model/data_model/plant_event.dart';
import 'care_logic.dart';
import 'care_rule_store.dart';

enum TimelineCategory { all, care, health }

/// User-facing projection of a [PlantEvent]. Persistence stays on the event log.
class PlantTimelineItem {
  final String id;
  final String plantId;
  final PlantEventType eventType;
  final DateTime timestamp;
  final String title;
  final String detail;
  final String? imagePath;
  final TimelineCategory category;

  const PlantTimelineItem({
    required this.id,
    required this.plantId,
    required this.eventType,
    required this.timestamp,
    required this.title,
    required this.detail,
    this.imagePath,
    required this.category,
  });
}

class PlantTimelineMapper {
  PlantTimelineMapper._();

  static const emptyTitle = 'Your plant story starts here';
  static const emptySubtitle =
      'Identification, care, and recovery will show up here.';

  static PlantTimelineItem fromEvent(PlantEvent event) {
    switch (event.eventType) {
      case PlantEventType.identification:
        final name = _string(event.payload['name']);
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: 'Identified',
          detail: name.isEmpty ? 'Saved to your plants.' : name,
          imagePath: _image(event.payload),
          category: TimelineCategory.all,
        );
      case PlantEventType.diagnosis:
        final issue = _string(event.payload['primaryIssue']);
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: 'Diagnosis recorded',
          detail: issue.isEmpty ? 'A diagnosis was saved.' : issue,
          imagePath: _image(event.payload),
          category: TimelineCategory.health,
        );
      case PlantEventType.treatment:
        final action = _string(event.payload['action']);
        final started = action.isEmpty || action == 'started';
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: started ? 'Treatment started' : 'Treatment updated',
          detail: started
              ? 'A treatment plan was saved.'
              : 'A treatment step was marked done.',
          category: TimelineCategory.health,
        );
      case PlantEventType.careCompletion:
        final careType = _string(event.payload['careType']);
        final label = CareLogic.displayType(careType);
        final watered = CareTypeNormalizer.isWatering(careType);
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: watered
              ? 'Watered'
              : (label.isEmpty ? 'Care completed' : '$label done'),
          detail: 'Care marked complete.',
          category: TimelineCategory.care,
        );
      case PlantEventType.recoveryCheckIn:
        final stage = _string(event.payload['stage']);
        final stageLabel = stage == 'day7' ? 'Day 7' : 'Day 3';
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: 'Recovery check-in',
          detail: '$stageLabel check-in saved.',
          imagePath: _image(event.payload),
          category: TimelineCategory.health,
        );
      case PlantEventType.plantPhoto:
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: 'Photo added',
          detail: 'A progress photo was saved.',
          imagePath: _image(event.payload),
          category: TimelineCategory.all,
        );
      case PlantEventType.outcome:
        final result = _string(event.payload['result']);
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: 'Recovery completed',
          detail: _outcomeDetail(result),
          category: TimelineCategory.health,
        );
      case PlantEventType.milestone:
        final title = _string(event.payload['title']);
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: title.isEmpty ? 'Milestone' : title,
          detail: title.isEmpty ? 'A milestone was recorded.' : title,
          category: TimelineCategory.all,
        );
      case PlantEventType.harvest:
        final quantity = event.payload['quantity'];
        final unit = _string(event.payload['unit']);
        final detail = quantity is num
            ? 'Harvest recorded${unit.isEmpty ? '' : ' · $quantity $unit'}.'
            : 'A harvest was recorded.';
        return PlantTimelineItem(
          id: event.id,
          plantId: event.plantId,
          eventType: event.eventType,
          timestamp: event.timestamp,
          title: 'Harvest recorded',
          detail: detail,
          imagePath: _image(event.payload),
          category: TimelineCategory.all,
        );
    }
  }

  /// Newest-first timeline for one plant. Unknown types are omitted.
  static List<PlantTimelineItem> itemsForPlant({
    required String plantId,
    required List<PlantEvent> events,
    TimelineCategory filter = TimelineCategory.all,
  }) {
    final items = <PlantTimelineItem>[];
    for (final event in events) {
      if (event.plantId != plantId) continue;
      items.add(fromEvent(event));
    }
    items.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    if (filter == TimelineCategory.all) return items;
    return items.where((item) => item.category == filter).toList();
  }

  /// Maps stored JSON; unknown/future event types return null.
  static PlantTimelineItem? tryMapJson(Map<String, dynamic> json) {
    final event = PlantEvent.tryFromJson(json);
    if (event == null) return null;
    return fromEvent(event);
  }

  static String _string(dynamic value) => value is String ? value.trim() : '';

  static String? _image(Map<String, dynamic> payload) {
    for (final key in ['imagePath', 'photoPath', 'newPhotoPath']) {
      final value = _string(payload[key]);
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  static String _outcomeDetail(String result) {
    switch (result) {
      case 'recovered':
        return 'Recovered.';
      case 'improved':
        return 'Improved.';
      case 'lost':
        return 'Did not make it.';
      case 'unknown':
        return 'Outcome unknown.';
      default:
        return 'Unresolved.';
    }
  }
}
