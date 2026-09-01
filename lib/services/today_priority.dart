import '../model/data_model/care_rule.dart';
import '../model/data_model/plant_context.dart';
import '../model/data_model/plant_event.dart';
import '../model/data_model/plant_model.dart';
import '../model/data_model/recovery_models.dart';
import '../model/data_model/reminder_model.dart';
import 'care_logic.dart';
import 'grow_logic.dart';
import 'recovery_logic.dart';

export '../model/data_model/plant_context.dart';

enum TodayActionKind { weather, recovery, care, grow, milestone }

class TodayWeatherSnapshot {
  final double temperatureC;
  final String description;

  const TodayWeatherSnapshot({
    required this.temperatureC,
    this.description = '',
  });

  /// Only surface weather when current conditions are genuinely extreme.
  /// No forecast/frost-tonight invention — current temperature only.
  bool get isCritical => temperatureC <= 2 || temperatureC >= 38;

  bool get isHeat => temperatureC >= 38;
}

class TodayMilestoneCandidate {
  final String id;
  final String plantId;
  final String title;
  final String subtitle;
  final DateTime timestamp;

  const TodayMilestoneCandidate({
    required this.id,
    required this.plantId,
    required this.title,
    required this.subtitle,
    required this.timestamp,
  });
}

class TodayAction {
  final TodayActionKind kind;
  final int rank;
  final String id;
  final String title;
  final String subtitle;
  final String ctaLabel;
  final bool dominant;
  final bool overdue;
  final String? plantId;
  final String? recoveryCaseId;
  final CheckInStage? checkInStage;
  final String? reminderId;
  final String? careRuleId;
  final DateTime? sortTime;

  const TodayAction({
    required this.kind,
    required this.rank,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaLabel,
    this.dominant = false,
    this.overdue = false,
    this.plantId,
    this.recoveryCaseId,
    this.checkInStage,
    this.reminderId,
    this.careRuleId,
    this.sortTime,
  });

  TodayAction copyWith({bool? dominant}) {
    return TodayAction(
      kind: kind,
      rank: rank,
      id: id,
      title: title,
      subtitle: subtitle,
      ctaLabel: ctaLabel,
      dominant: dominant ?? this.dominant,
      overdue: overdue,
      plantId: plantId,
      recoveryCaseId: recoveryCaseId,
      checkInStage: checkInStage,
      reminderId: reminderId,
      careRuleId: careRuleId,
      sortTime: sortTime,
    );
  }
}

class TodayPriorityResult {
  final List<TodayAction> cards;

  const TodayPriorityResult(this.cards);

  bool get isEmpty => cards.isEmpty;

  static const emptyTitle = 'Nothing needed today';
  static const emptySubtitle = "Your plants are on track.";
}

/// Deterministic Today projection. Not a second task database.
class TodayPriorityResolver {
  static const maxPrimaryCards = 3;

  static const weatherRank = 1;
  static const recoveryRank = 2;
  static const careRank = 3;
  static const growRank = 4;
  static const milestoneRank = 5;

  static TodayPriorityResult resolve({
    required DateTime now,
    required List<RecoveryCase> cases,
    required Map<String, String> plantNames,
    Map<String, String> diagnosisSummaries = const {},
    List<PlantReminder> reminders = const [],
    List<CareRule> careRules = const [],
    TodayWeatherSnapshot? weather,
    List<TodayMilestoneCandidate> milestones = const [],
    List<GrowDueAction> growActions = const [],
    Iterable<PlantWeatherContext> plantWeatherContexts = const [],
  }) {
    final recovery = _recoveryCards(
      now: now,
      cases: cases,
      plantNames: plantNames,
      diagnosisSummaries: diagnosisSummaries,
    );
    final care = _careCards(
      now: now,
      reminders: reminders,
      careRules: careRules,
      plantNames: plantNames,
    );
    final milestoneCards = _milestoneCards(milestones);

    final ordered = <TodayAction>[];

    if (shouldShowCriticalWeather(
      weather: weather,
      plantContexts: plantWeatherContexts,
    )) {
      ordered.add(_weatherCard(weather!));
    }
    ordered.addAll(recovery);
    ordered.addAll(care);
    ordered.addAll(_growCards(growActions));
    ordered.addAll(milestoneCards);

    final capped = ordered.take(maxPrimaryCards).toList();
    if (capped.isNotEmpty) {
      capped[0] = capped[0].copyWith(dominant: true);
    }
    return TodayPriorityResult(capped);
  }

  /// Critical weather is eligible only when temperature is extreme **and**
  /// at least one plant has a known outdoor-exposed placement.
  /// Saved plants without placement data do not qualify.
  static bool shouldShowCriticalWeather({
    required TodayWeatherSnapshot? weather,
    required Iterable<PlantWeatherContext> plantContexts,
  }) {
    if (weather == null || !weather.isCritical) return false;
    return plantContexts.any((c) => c.isAffectedByOutdoorConditions);
  }

  /// Use the plant's stored placement. Missing records stay unknown.
  /// Do not infer placement from name, care copy, or "has any saved plant".
  static PlantWeatherContext contextForPlant(Plant? plant) =>
      plant?.placement ?? PlantWeatherContext.unknown;

  /// Kept for older tests; equivalent to an unknown/unspecified plant.
  static PlantWeatherContext contextForCurrentPlant() =>
      PlantWeatherContext.unknown;

  static List<TodayMilestoneCandidate> milestonesFromEvents({
    required List<PlantEvent> events,
    required DateTime now,
    required Map<String, String> plantNames,
  }) {
    final cutoff = now.subtract(const Duration(hours: 48));
    final out = <TodayMilestoneCandidate>[];
    for (final event in events) {
      if (event.eventType != PlantEventType.outcome) continue;
      if (event.timestamp.isBefore(cutoff)) continue;
      final plantName = plantNames[event.plantId] ?? 'Your plant';
      final result = event.payload['result'] as String? ?? '';
      if (result == 'lost' || result == 'unknown') continue;
      final label = result == 'recovered'
          ? 'looking healthier'
          : result == 'improved'
          ? 'doing a bit better'
          : 'update recorded';
      out.add(
        TodayMilestoneCandidate(
          id: event.id,
          plantId: event.plantId,
          title: plantName,
          subtitle: '$plantName is $label.',
          timestamp: event.timestamp,
        ),
      );
    }
    out.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return out;
  }

  static TodayAction _weatherCard(TodayWeatherSnapshot weather) {
    final heat = weather.isHeat;
    return TodayAction(
      kind: TodayActionKind.weather,
      rank: weatherRank,
      id: 'weather-critical',
      title: heat ? 'Protect plants from the heat' : 'A chilly stretch',
      subtitle: heat
          ? '${weather.temperatureC.round()}° — give outdoor plants some shade if you can.'
          : '${weather.temperatureC.round()}° — bring sensitive plants in if they’re outside.',
      ctaLabel: 'See weather',
      sortTime: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static List<TodayAction> _recoveryCards({
    required DateTime now,
    required List<RecoveryCase> cases,
    required Map<String, String> plantNames,
    required Map<String, String> diagnosisSummaries,
  }) {
    final cards = <TodayAction>[];
    for (final recoveryCase in cases) {
      final due = RecoveryLogic.checkInDue(recoveryCase, now);
      if (due == null) continue;
      final plantName = _plantLabel(plantNames[recoveryCase.plantId]);
      final stageLabel = due.stage == CheckInStage.day3 ? 'Day 3' : 'Day 7';
      final noticed = diagnosisSummaries[recoveryCase.diagnosisId];
      final reason = (noticed != null && noticed.trim().isNotEmpty)
          ? 'We noticed possible ${noticed.trim()}.'
          : 'See how it’s responding.';
      final subtitle = due.isOverdue
          ? '$stageLabel — $reason Whenever you’re ready.'
          : '$stageLabel — see how it’s responding.';
      cards.add(
        TodayAction(
          kind: TodayActionKind.recovery,
          rank: recoveryRank,
          id: 'recovery-${recoveryCase.id}',
          title: 'Check on $plantName',
          subtitle: subtitle,
          ctaLabel: 'Check now',
          overdue: due.isOverdue,
          plantId: recoveryCase.plantId,
          recoveryCaseId: recoveryCase.id,
          checkInStage: due.stage,
          sortTime: due.dueAt,
        ),
      );
    }
    cards.sort((a, b) => (a.sortTime ?? now).compareTo(b.sortTime ?? now));
    return cards;
  }

  static List<TodayAction> _careCards({
    required DateTime now,
    required List<PlantReminder> reminders,
    required List<CareRule> careRules,
    required Map<String, String> plantNames,
  }) {
    final cards = <TodayAction>[];

    final dueRules = careRules.where((r) => CareLogic.isDue(r, now)).toList()
      ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));
    for (final rule in dueRules) {
      final plantName = _plantLabel(plantNames[rule.plantId]);
      final task = rule.careType.replaceFirst('PlantFollow: ', '');
      cards.add(
        TodayAction(
          kind: TodayActionKind.care,
          rank: careRank,
          id: 'care-rule-${rule.id}',
          title: '$task — $plantName',
          subtitle: CareLogic.whyDue(rule, now),
          ctaLabel: 'Done',
          plantId: rule.plantId,
          reminderId: rule.reminderId,
          careRuleId: rule.id,
          sortTime: rule.nextDueAt,
        ),
      );
    }

    final dueReminders =
        reminders.where((r) => _careDueOnOrBefore(r, now)).toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    for (final reminder in dueReminders) {
      final covered = careRules.any(
        (rule) =>
            rule.enabled && CareLogic.reminderCoveredByRule(reminder, rule),
      );
      if (covered) continue;
      final task = reminder.taskType.replaceFirst('PlantFollow: ', '');
      final plantName = _plantLabel(reminder.plantName);
      cards.add(
        TodayAction(
          kind: TodayActionKind.care,
          rank: careRank,
          id: 'care-${reminder.id}',
          title: '$task — $plantName',
          subtitle: _careWhy(reminder, now),
          ctaLabel: 'Done',
          plantId: reminder.plantId,
          reminderId: reminder.id,
          sortTime: reminder.dateTime,
        ),
      );
    }

    cards.sort((a, b) => (a.sortTime ?? now).compareTo(b.sortTime ?? now));
    return cards;
  }

  static List<TodayAction> _growCards(List<GrowDueAction> growActions) {
    return growActions
        .map(
          (action) => TodayAction(
            kind: TodayActionKind.grow,
            rank: growRank,
            id: action.id,
            title: action.title,
            subtitle: action.subtitle,
            ctaLabel: action.ctaLabel,
            plantId: action.plantId,
            sortTime: action.sortTime,
          ),
        )
        .toList();
  }

  static List<TodayAction> _milestoneCards(
    List<TodayMilestoneCandidate> milestones,
  ) {
    return milestones
        .map(
          (m) => TodayAction(
            kind: TodayActionKind.milestone,
            rank: milestoneRank,
            id: 'milestone-${m.id}',
            title: m.title,
            subtitle: m.subtitle,
            ctaLabel: 'View plant',
            plantId: m.plantId,
            sortTime: m.timestamp,
          ),
        )
        .toList();
  }

  static bool _careDueOnOrBefore(PlantReminder reminder, DateTime now) {
    if (reminder.isCompleted) return false;
    final dueDay = DateTime(
      reminder.dateTime.year,
      reminder.dateTime.month,
      reminder.dateTime.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    return !dueDay.isAfter(today);
  }

  static String _careWhy(PlantReminder reminder, DateTime now) {
    final dueDay = DateTime(
      reminder.dateTime.year,
      reminder.dateTime.month,
      reminder.dateTime.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    if (dueDay.isBefore(today)) {
      return 'Still on the list — mark it when you can.';
    }
    return 'On today’s care list.';
  }

  static String _plantLabel(String? name) {
    final trimmed = name?.trim() ?? '';
    return trimmed.isEmpty ? 'your plant' : trimmed;
  }
}
