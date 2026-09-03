import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../model/data_model/plant_model.dart';
import '../../../services/identification_result.dart';
import '../../../services/identify_logic.dart';

class IdentifyTrustCard extends StatelessWidget {
  final Plant plant;
  final IdentificationResult result;
  final ValueChanged<IdentifyCandidate>? onSelectAlternative;
  final VoidCallback? onRetry;

  const IdentifyTrustCard({
    super.key,
    required this.plant,
    required this.result,
    this.onSelectAlternative,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ConfidenceChip(result: result),
        const SizedBox(height: 8),
        Text(
          result.titlePrefix,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF667068),
          ),
        ),
        if (result.identityStatus != IdentityStatus.unconfirmed) ...[
          const SizedBox(height: 2),
          Text(
            result.commonName,
            key: const Key('identify_common_name'),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF172019),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ] else ...[
          const SizedBox(height: 2),
          Text(
            result.displayedName,
            key: const Key('identify_common_name'),
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF172019),
            ),
          ),
          if (result.commonName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Possible match: ${result.commonName}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF667068),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
        if (result.scientificName.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            result.scientificName,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        if (result.supportingCopy.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            result.supportingCopy,
            key: const Key('identify_supporting_copy'),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ],
        if (result.evidenceSummary.isNotEmpty &&
            result.identityStatus == IdentityStatus.confirmed) ...[
          const SizedBox(height: 4),
          Text(
            result.evidenceSummary,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.3,
            ),
          ),
        ],
      ],
    );
  }
}

class IdentifyTrustExtras extends StatelessWidget {
  final IdentificationResult result;
  final ValueChanged<IdentifyCandidate>? onSelectAlternative;
  final VoidCallback? onRetry;

  const IdentifyTrustExtras({
    super.key,
    required this.result,
    this.onSelectAlternative,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final showRetryTips = result.identificationUncertain &&
        result.retryTips.isNotEmpty;
    final showAlternatives = result.alternatives.isNotEmpty;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IdentifySafetySummary(
            safety: result.safety,
            identificationUncertain: result.identificationUncertain,
          ),
          if (showRetryTips) ...[
            const SizedBox(height: 12),
            Text(
              IdentificationResult.imageQualityCopy(result.imageQuality).isEmpty
                  ? 'For a closer look'
                  : IdentificationResult.imageQualityCopy(result.imageQuality),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 6),
            ...result.retryTips.take(IdentificationResult.maxRetryTips).map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $tip',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                ),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: onRetry,
                child: Text(
                  IdentifyLogic.retryAction,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
              ),
          ],
          if (showAlternatives) ...[
            const SizedBox(height: 8),
            Text(
              'Other possible matches',
              key: const Key('identify_alternatives'),
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2E7D32),
              ),
            ),
            const SizedBox(height: 6),
            ...result.alternatives.take(IdentificationResult.maxAlternatives).map(
              (candidate) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    key: Key('identify_alt_${candidate.commonName}'),
                    onTap: onSelectAlternative == null
                        ? null
                        : () => onSelectAlternative!(candidate),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAF7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF4CAF50).withOpacity(0.15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            candidate.commonName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF1B5E20),
                            ),
                          ),
                          if (candidate.scientificName.isNotEmpty)
                            Text(
                              candidate.scientificName,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (candidate.confidence != null)
                            Text(
                              _descriptor(candidate.confidence!),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  String _descriptor(SpeciesConfidence confidence) {
    switch (confidence) {
      case SpeciesConfidence.high:
        return 'Strong match';
      case SpeciesConfidence.medium:
        return 'Likely match';
      case SpeciesConfidence.low:
        return 'Needs another look';
      case SpeciesConfidence.unknown:
        return '';
    }
  }
}

class IdentifySafetySummary extends StatefulWidget {
  final PlantSafety safety;
  final bool identificationUncertain;

  const IdentifySafetySummary({
    super.key,
    required this.safety,
    required this.identificationUncertain,
  });

  @override
  State<IdentifySafetySummary> createState() => _IdentifySafetySummaryState();
}

class _IdentifySafetySummaryState extends State<IdentifySafetySummary> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final safety = widget.safety;
    final supporting = safety.supportingCopy(
      identificationUncertain: widget.identificationUncertain,
    );
    final icon = safety.isToxic
        ? Icons.warning_amber_rounded
        : safety.isNonToxic
            ? Icons.check_circle_outline
            : Icons.info_outline;
    final color = safety.isToxic
        ? const Color(0xFFC77800)
        : const Color(0xFF5D6D57);

    return Semantics(
      label: '${safety.headline}. $supporting',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            key: const Key('identify_safety'),
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  safety.headline,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          if (supporting.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              supporting,
              key: const Key('identify_safety_copy'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[800],
                height: 1.35,
              ),
            ),
          ],
          if (safety.details.isNotEmpty &&
              safety.details != supporting &&
              safety.details != safety.headline)
            TextButton(
              onPressed: () => setState(() => _expanded = !_expanded),
              child: Text(
                _expanded ? 'Hide safety details' : 'View safety details',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2E7D32),
                ),
              ),
            ),
          if (_expanded && safety.details.isNotEmpty)
            Text(
              safety.details,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.grey[800],
                height: 1.35,
              ),
            ),
        ],
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final IdentificationResult result;

  const _ConfidenceChip({required this.result});

  @override
  Widget build(BuildContext context) {
    final Color background;
    final Color foreground;
    final IconData icon;
    switch (result.identityStatus) {
      case IdentityStatus.confirmed:
        background = const Color(0xFFE8F5E9);
        foreground = const Color(0xFF2E7D32);
        icon = Icons.verified_outlined;
      case IdentityStatus.likely:
        background = const Color(0xFFFFF8E1);
        foreground = const Color(0xFF8A6D1B);
        icon = Icons.help_outline;
      case IdentityStatus.unconfirmed:
        background = const Color(0xFFF3F4F3);
        foreground = const Color(0xFF5D6D57);
        icon = Icons.search;
    }

    return Semantics(
      label: result.confidenceChipLabel,
      child: Container(
        key: const Key('identify_confidence_chip'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 6),
            Text(
              result.confidenceChipLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
