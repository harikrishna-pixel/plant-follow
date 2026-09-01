// Adaptive grow-plan domain. Derived dates are not stored as truth.

enum GrowStage {
  sown,
  germinating,
  seedling,
  vegetative,
  flowering,
  fruiting,
  harvestReady,
  completed,
}

enum GrowAnchorType {
  sowed,
  germinated,
  transplanted,
  floweringStarted,
  fruitingStarted,
  firstHarvest,
}

enum GrowPlanStatus { active, completed }

enum HarvestRepeat { oneTime, repeated }

extension GrowStageUi on GrowStage {
  String get confirmedLabel {
    switch (this) {
      case GrowStage.sown:
        return 'Sowed';
      case GrowStage.germinating:
        return 'Sprouting';
      case GrowStage.seedling:
        return 'Seedling';
      case GrowStage.vegetative:
        return 'Growing';
      case GrowStage.flowering:
        return 'Flowering';
      case GrowStage.fruiting:
        return 'Fruiting';
      case GrowStage.harvestReady:
        return 'Ready to harvest';
      case GrowStage.completed:
        return 'Season complete';
    }
  }

  String get likelySoonLabel {
    switch (this) {
      case GrowStage.germinating:
        return 'sprouting';
      case GrowStage.seedling:
        return 'seedling';
      case GrowStage.vegetative:
        return 'ready to move on';
      case GrowStage.flowering:
        return 'flowering';
      case GrowStage.fruiting:
        return 'fruiting';
      case GrowStage.harvestReady:
        return 'ready to harvest';
      case GrowStage.sown:
      case GrowStage.completed:
        return confirmedLabel.toLowerCase();
    }
  }
}

extension GrowAnchorTypeCodec on GrowAnchorType {
  String get wireName {
    switch (this) {
      case GrowAnchorType.sowed:
        return 'sowed';
      case GrowAnchorType.germinated:
        return 'germinated';
      case GrowAnchorType.transplanted:
        return 'transplanted';
      case GrowAnchorType.floweringStarted:
        return 'flowering_started';
      case GrowAnchorType.fruitingStarted:
        return 'fruiting_started';
      case GrowAnchorType.firstHarvest:
        return 'first_harvest';
    }
  }

  String get milestoneTitle {
    switch (this) {
      case GrowAnchorType.sowed:
        return 'Sowed';
      case GrowAnchorType.germinated:
        return 'Sprouted';
      case GrowAnchorType.transplanted:
        return 'Transplanted';
      case GrowAnchorType.floweringStarted:
        return 'Flowering started';
      case GrowAnchorType.fruitingStarted:
        return 'First fruit';
      case GrowAnchorType.firstHarvest:
        return 'First harvest';
    }
  }

  String get confirmLabel {
    switch (this) {
      case GrowAnchorType.sowed:
        return 'I sowed it';
      case GrowAnchorType.germinated:
        return 'It sprouted';
      case GrowAnchorType.transplanted:
        return 'I transplanted it';
      case GrowAnchorType.floweringStarted:
        return 'Flowers appeared';
      case GrowAnchorType.fruitingStarted:
        return 'First fruit';
      case GrowAnchorType.firstHarvest:
        return 'Harvested';
    }
  }

  GrowStage get confirmedStage {
    switch (this) {
      case GrowAnchorType.sowed:
        return GrowStage.sown;
      case GrowAnchorType.germinated:
        return GrowStage.seedling;
      case GrowAnchorType.transplanted:
        return GrowStage.vegetative;
      case GrowAnchorType.floweringStarted:
        return GrowStage.flowering;
      case GrowAnchorType.fruitingStarted:
        return GrowStage.fruiting;
      case GrowAnchorType.firstHarvest:
        return GrowStage.harvestReady;
    }
  }

  static GrowAnchorType? tryFromWire(String? value) {
    switch (value) {
      case 'sowed':
        return GrowAnchorType.sowed;
      case 'germinated':
        return GrowAnchorType.germinated;
      case 'transplanted':
        return GrowAnchorType.transplanted;
      case 'flowering_started':
        return GrowAnchorType.floweringStarted;
      case 'fruiting_started':
        return GrowAnchorType.fruitingStarted;
      case 'first_harvest':
        return GrowAnchorType.firstHarvest;
      default:
        return null;
    }
  }
}

class GrowAnchor {
  final GrowAnchorType type;
  final DateTime confirmedAt;

  const GrowAnchor({required this.type, required this.confirmedAt});

  Map<String, dynamic> toJson() => {
    'type': type.wireName,
    'confirmedAt': confirmedAt.toIso8601String(),
  };

  static GrowAnchor? tryFromJson(Map<String, dynamic> json) {
    final type = GrowAnchorTypeCodec.tryFromWire(json['type'] as String?);
    final raw = json['confirmedAt'];
    if (type == null || raw is! String) return null;
    return GrowAnchor(type: type, confirmedAt: DateTime.parse(raw));
  }
}

class GrowPlan {
  final String id;
  final String plantId;
  final String cropId;
  final DateTime createdAt;
  final GrowPlanStatus status;
  final HarvestRepeat harvestRepeat;
  final List<GrowAnchor> anchors;
  final String? locationId;
  final String notes;
  final DateTime? completedAt;

  GrowPlan({
    required this.id,
    required this.plantId,
    required this.cropId,
    required this.createdAt,
    this.status = GrowPlanStatus.active,
    this.harvestRepeat = HarvestRepeat.oneTime,
    List<GrowAnchor>? anchors,
    this.locationId,
    this.notes = '',
    this.completedAt,
  }) : anchors = List.unmodifiable(anchors ?? const []);

  GrowAnchor? anchor(GrowAnchorType type) {
    for (final item in anchors) {
      if (item.type == type) return item;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'plantId': plantId,
    'cropId': cropId,
    'createdAt': createdAt.toIso8601String(),
    'status': status == GrowPlanStatus.completed ? 'completed' : 'active',
    'harvestRepeat': harvestRepeat == HarvestRepeat.repeated
        ? 'repeated'
        : 'one_time',
    'anchors': anchors.map((a) => a.toJson()).toList(),
    'locationId': locationId,
    'notes': notes,
    'completedAt': completedAt?.toIso8601String(),
  };

  factory GrowPlan.fromJson(Map<String, dynamic> json) {
    final rawAnchors = json['anchors'];
    final anchors = <GrowAnchor>[];
    if (rawAnchors is List) {
      for (final item in rawAnchors) {
        if (item is! Map) continue;
        final parsed = GrowAnchor.tryFromJson(Map<String, dynamic>.from(item));
        if (parsed != null) anchors.add(parsed);
      }
    }
    return GrowPlan(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      cropId: json['cropId'] as String? ?? CropCatalog.genericId,
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: json['status'] == 'completed'
          ? GrowPlanStatus.completed
          : GrowPlanStatus.active,
      harvestRepeat: json['harvestRepeat'] == 'repeated'
          ? HarvestRepeat.repeated
          : HarvestRepeat.oneTime,
      anchors: anchors,
      locationId: json['locationId'] as String?,
      notes: json['notes'] as String? ?? '',
      completedAt: json['completedAt'] is String
          ? DateTime.parse(json['completedAt'] as String)
          : null,
    );
  }

  GrowPlan copyWith({
    String? cropId,
    GrowPlanStatus? status,
    HarvestRepeat? harvestRepeat,
    List<GrowAnchor>? anchors,
    String? locationId,
    String? notes,
    DateTime? completedAt,
  }) {
    return GrowPlan(
      id: id,
      plantId: plantId,
      cropId: cropId ?? this.cropId,
      createdAt: createdAt,
      status: status ?? this.status,
      harvestRepeat: harvestRepeat ?? this.harvestRepeat,
      anchors: anchors ?? this.anchors,
      locationId: locationId ?? this.locationId,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class HarvestRecord {
  final String id;
  final String plantId;
  final String growPlanId;
  final DateTime timestamp;
  final double? quantity;
  final String? unit;
  final String? note;
  final String? photoPath;

  const HarvestRecord({
    required this.id,
    required this.plantId,
    required this.growPlanId,
    required this.timestamp,
    this.quantity,
    this.unit,
    this.note,
    this.photoPath,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'plantId': plantId,
    'growPlanId': growPlanId,
    'timestamp': timestamp.toIso8601String(),
    'quantity': quantity,
    'unit': unit,
    'note': note,
    'photoPath': photoPath,
  };

  factory HarvestRecord.fromJson(Map<String, dynamic> json) {
    return HarvestRecord(
      id: json['id'] as String,
      plantId: json['plantId'] as String,
      growPlanId: json['growPlanId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      quantity: (json['quantity'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      note: json['note'] as String?,
      photoPath: json['photoPath'] as String?,
    );
  }
}

class CropProfile {
  final String id;
  final String label;
  final HarvestRepeat harvestRepeat;
  final List<GrowStage> sequence;
  final List<GrowAnchorType> anchors;
  final Map<GrowStage, int> offsetDays;

  const CropProfile({
    required this.id,
    required this.label,
    required this.harvestRepeat,
    required this.sequence,
    required this.anchors,
    required this.offsetDays,
  });
}

class CropCatalog {
  CropCatalog._();

  static const genericId = 'generic';
  static const tomatoId = 'tomato';
  static const leafyId = 'leafy';

  static const generic = CropProfile(
    id: genericId,
    label: 'General crop',
    harvestRepeat: HarvestRepeat.oneTime,
    sequence: [
      GrowStage.sown,
      GrowStage.germinating,
      GrowStage.seedling,
      GrowStage.vegetative,
      GrowStage.harvestReady,
    ],
    anchors: [
      GrowAnchorType.sowed,
      GrowAnchorType.germinated,
      GrowAnchorType.firstHarvest,
    ],
    offsetDays: {
      GrowStage.sown: 0,
      GrowStage.germinating: 0,
      GrowStage.seedling: 7,
      GrowStage.vegetative: 14,
      GrowStage.harvestReady: 30,
    },
  );

  static const tomato = CropProfile(
    id: tomatoId,
    label: 'Tomato',
    harvestRepeat: HarvestRepeat.repeated,
    sequence: [
      GrowStage.sown,
      GrowStage.germinating,
      GrowStage.seedling,
      GrowStage.vegetative,
      GrowStage.flowering,
      GrowStage.fruiting,
      GrowStage.harvestReady,
    ],
    anchors: [
      GrowAnchorType.sowed,
      GrowAnchorType.germinated,
      GrowAnchorType.transplanted,
      GrowAnchorType.floweringStarted,
      GrowAnchorType.fruitingStarted,
      GrowAnchorType.firstHarvest,
    ],
    offsetDays: {
      GrowStage.sown: 0,
      GrowStage.germinating: 0,
      GrowStage.seedling: 7,
      GrowStage.vegetative: 14,
      GrowStage.flowering: 28,
      GrowStage.fruiting: 14,
      GrowStage.harvestReady: 14,
    },
  );

  static const leafy = CropProfile(
    id: leafyId,
    label: 'Leafy greens',
    harvestRepeat: HarvestRepeat.oneTime,
    sequence: [
      GrowStage.sown,
      GrowStage.germinating,
      GrowStage.seedling,
      GrowStage.vegetative,
      GrowStage.harvestReady,
    ],
    anchors: [
      GrowAnchorType.sowed,
      GrowAnchorType.germinated,
      GrowAnchorType.firstHarvest,
    ],
    offsetDays: {
      GrowStage.sown: 0,
      GrowStage.germinating: 0,
      GrowStage.seedling: 5,
      GrowStage.vegetative: 10,
      GrowStage.harvestReady: 25,
    },
  );

  static const List<CropProfile> all = [generic, tomato, leafy];

  static CropProfile byId(String? id) {
    for (final profile in all) {
      if (profile.id == id) return profile;
    }
    return generic;
  }
}
