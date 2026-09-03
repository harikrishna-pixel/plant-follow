import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../model/data_model/care_rule.dart';
import '../../../model/data_model/plant_model.dart';
import '../../../provider/care_rule_provider.dart';
import '../../../provider/location_provider.dart';
import '../../../provider/reminder_provider.dart';
import '../../../services/care_completion.dart';
import '../../../services/care_context_resolver.dart';
import '../../../services/care_logic.dart';
import '../../../services/location_weather_cache.dart';
import '../../../services/weather_service.dart';
import '../../../services/weather_snapshot.dart';

class PlantCareTab extends StatelessWidget {
  final Plant plant;

  const PlantCareTab({super.key, required this.plant});

  static const emptyTitle = 'No care schedule yet';

  @override
  Widget build(BuildContext context) {
    final rules =
        context
            .watch<CareRuleProvider>()
            .rules
            .where((r) => r.enabled && r.plantId == plant.id)
            .toList()
          ..sort((a, b) => a.nextDueAt.compareTo(b.nextDueAt));

    if (rules.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyTitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 15, color: Colors.grey[600]),
          ),
        ),
      );
    }

    final now = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: rules.length,
      itemBuilder: (context, index) {
        return _CareRuleCard(rule: rules[index], now: now, plant: plant);
      },
    );
  }
}

class _CareRuleCard extends StatefulWidget {
  final CareRule rule;
  final DateTime now;
  final Plant plant;

  const _CareRuleCard({
    required this.rule,
    required this.now,
    required this.plant,
  });

  @override
  State<_CareRuleCard> createState() => _CareRuleCardState();
}

class _CareRuleCardState extends State<_CareRuleCard> {
  bool _showWhy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureWeather());
  }

  Future<void> _ensureWeather() async {
    final locations = context.read<LocationProvider>();
    final location = locations.forPlant(widget.plant);
    if (location == null) return;
    if (LocationWeatherCache.instance.peek(location.id) != null) return;
    await LocationWeatherCache.instance.getOrFetch(
      location: location,
      loader: LocationWeatherLookup(WeatherService()).forLocation,
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    final now = widget.now;
    final due = CareLogic.isDue(rule, now);
    final overdue = CareLogic.isOverdue(rule, now);
    final last = rule.lastCompletedAt;
    final locations = context.watch<LocationProvider>();
    final location = locations.forPlant(widget.plant);
    WeatherSnapshot? weather;
    if (location != null) {
      weather = LocationWeatherCache.instance.peek(location.id);
    }
    final decision = CareContextResolver.evaluate(
      plant: widget.plant,
      rule: rule,
      location: location,
      weather: weather,
      now: now,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            CareLogic.displayType(rule.careType),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B5E20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            overdue
                ? 'Still on the list — mark it when you can.'
                : due
                ? 'Due today'
                : 'Next ${DateFormat.MMMd().format(rule.nextDueAt)}',
            style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
          ),
          if (last != null) ...[
            const SizedBox(height: 2),
            Text(
              'Last done ${DateFormat.MMMd().format(last)}.',
              style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
          if (due && !decision.weatherApplied) ...[
            const SizedBox(height: 4),
            Text(
              CareLogic.whyDue(rule, now),
              style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
          if (decision.weatherApplied && decision.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  decision.observedRain
                      ? Icons.water_drop_outlined
                      : Icons.wb_sunny_outlined,
                  size: 16,
                  color: const Color(0xFF5D6D57),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    decision.reason,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.grey[800],
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () => setState(() => _showWhy = !_showWhy),
              child: Text(
                _showWhy ? 'Hide' : 'Why?',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
            if (_showWhy)
              Text(
                decision.explanation,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.35,
                  color: Colors.grey[700],
                ),
              ),
          ],
          if (due) ...[
            const SizedBox(height: 10),
            if (decision.state == CareContextState.maybeHandledByRain)
              Row(
                children: [
                  TextButton(
                    onPressed: () async {
                      await context
                          .read<CareRuleProvider>()
                          .rejectRainSuggestion(rule);
                    },
                    child: Text(
                      'Still needs water',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      await CareCompletion.complete(
                        rule: rule,
                        careRules: context.read<CareRuleProvider>(),
                        reminders: context.read<ReminderProvider>(),
                        extraPayload: CareContextResolver.rainConfirmedPayload(
                          location: location,
                          weather: weather,
                        ),
                      );
                    },
                    child: Text(
                      'Rain handled it',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () async {
                    await CareCompletion.complete(
                      rule: rule,
                      careRules: context.read<CareRuleProvider>(),
                      reminders: context.read<ReminderProvider>(),
                    );
                  },
                  child: Text(
                    'Mark done',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
