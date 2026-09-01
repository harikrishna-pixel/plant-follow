import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../services/plant_local.dart';
import '../../../services/plant_timeline.dart';

class PlantTimelineTab extends StatefulWidget {
  final String plantId;

  const PlantTimelineTab({super.key, required this.plantId});

  @override
  State<PlantTimelineTab> createState() => _PlantTimelineTabState();
}

class _PlantTimelineTabState extends State<PlantTimelineTab> {
  TimelineCategory _filter = TimelineCategory.all;

  @override
  Widget build(BuildContext context) {
    final events = LocalStorageService.getPlantEvents(widget.plantId);
    final items = PlantTimelineMapper.itemsForPlant(
      plantId: widget.plantId,
      events: events,
      filter: _filter,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 8,
            children: [
              _chip('All', TimelineCategory.all),
              _chip('Care', TimelineCategory.care),
              _chip('Health', TimelineCategory.health),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          PlantTimelineMapper.emptyTitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1B5E20),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          PlantTimelineMapper.emptySubtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return _TimelineTile(item: items[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _chip(String label, TimelineCategory value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 12)),
      selected: selected,
      selectedColor: const Color(0xFFC8E6C9),
      onSelected: (_) => setState(() => _filter = value),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final PlantTimelineItem item;

  const _TimelineTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final image = item.imagePath;
    final hasFile = image != null && File(image).existsSync();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF4CAF50),
                  shape: BoxShape.circle,
                ),
              ),
              Container(width: 2, height: 48, color: const Color(0xFFC8E6C9)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('MMM d, yyyy · h:mm a').format(item.timestamp),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (item.detail.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.detail,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                  if (hasFile) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(image),
                        height: 88,
                        width: 88,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
