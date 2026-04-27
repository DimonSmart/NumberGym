import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:trainer_core/trainer_core.dart';
import 'package:verb_gym_content/verb_gym_content.dart';

enum VerbTimelineRegion { past, present, future }

enum VerbTimelineAspect { simple, continuous, perfect }

class VerbTenseTimelineCardData {
  const VerbTenseTimelineCardData({
    required this.tenseId,
    required this.title,
    required this.region,
    required this.aspect,
    required this.isSelected,
  });

  final String tenseId;
  final String title;
  final VerbTimelineRegion region;
  final VerbTimelineAspect aspect;
  final bool isSelected;
}

class VerbTenseTimelineLabels {
  const VerbTenseTimelineLabels({required this.now, required this.tenseTitles});

  final String now;
  final Map<String, String> tenseTitles;

  factory VerbTenseTimelineLabels.forLanguage(LearningLanguage language) {
    switch (language) {
      case LearningLanguage.spanish:
        return spanish;
      case LearningLanguage.english:
      case LearningLanguage.french:
      case LearningLanguage.german:
      case LearningLanguage.hebrew:
        return english;
    }
  }

  String titleFor(String tenseId) {
    return tenseTitles[tenseId] ??
        english.tenseTitles[tenseId] ??
        _splitCamelCase(tenseId);
  }

  static const english = VerbTenseTimelineLabels(
    now: 'NOW',
    tenseTitles: <String, String>{
      VerbTenseIds.presentIndicative: 'Present indicative',
      VerbTenseIds.presentPerfect: 'Present perfect',
      VerbTenseIds.preterite: 'Simple past',
      VerbTenseIds.imperfectIndicative: 'Imperfect indicative',
      VerbTenseIds.futureSimple: 'Future simple',
      VerbTenseIds.conditionalSimple: 'Conditional simple',
      VerbTenseIds.presentSubjunctive: 'Present subjunctive',
      VerbTenseIds.imperfectSubjunctive: 'Imperfect subjunctive',
      _presentContinuousTenseId: 'Present continuous',
      _pastPerfectTenseId: 'Past perfect',
      _futureContinuousTenseId: 'Future continuous',
      _futurePerfectTenseId: 'Future perfect',
    },
  );

  static const spanish = VerbTenseTimelineLabels(
    now: 'AHORA',
    tenseTitles: <String, String>{
      VerbTenseIds.presentIndicative: 'Presente de indicativo',
      VerbTenseIds.presentPerfect: 'Pretérito perfecto',
      VerbTenseIds.preterite: 'Pretérito indefinido',
      VerbTenseIds.imperfectIndicative: 'Pretérito imperfecto',
      VerbTenseIds.futureSimple: 'Futuro simple',
      VerbTenseIds.conditionalSimple: 'Condicional simple',
      VerbTenseIds.presentSubjunctive: 'Presente de subjuntivo',
      VerbTenseIds.imperfectSubjunctive: 'Imperfecto de subjuntivo',
      _presentContinuousTenseId: 'Presente continuo',
      _pastPerfectTenseId: 'Pluscuamperfecto',
      _futureContinuousTenseId: 'Futuro continuo',
      _futurePerfectTenseId: 'Futuro perfecto',
    },
  );
}

class VerbTenseTimelineHint extends StatelessWidget {
  const VerbTenseTimelineHint({
    super.key,
    required this.currentTenseId,
    required this.labels,
  });

  final String currentTenseId;
  final VerbTenseTimelineLabels labels;

  @override
  Widget build(BuildContext context) {
    final cards = buildVerbTenseTimelineCards(
      currentTenseId: currentTenseId,
      labels: labels,
    );
    if (cards.isEmpty) {
      return const SizedBox.shrink();
    }
    return VerbTenseTimelineStrip(cards: cards, nowLabel: labels.now);
  }
}

class VerbTenseTimelineStrip extends StatelessWidget {
  const VerbTenseTimelineStrip({
    super.key,
    required this.cards,
    required this.nowLabel,
  }) : assert(cards.length == 3);

  final List<VerbTenseTimelineCardData> cards;
  final String nowLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 430;
        final gap = compact ? 8.0 : 12.0;
        final height = compact ? 118.0 : 138.0;
        return SizedBox(
          height: height,
          child: Row(
            children: [
              for (var index = 0; index < cards.length; index += 1) ...[
                if (index > 0) SizedBox(width: gap),
                Expanded(
                  child: _VerbTenseTimelineCard(
                    data: cards[index],
                    nowLabel: nowLabel,
                    compact: compact,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

List<VerbTenseTimelineCardData> buildVerbTenseTimelineCards({
  required String currentTenseId,
  required VerbTenseTimelineLabels labels,
}) {
  final selectedDefinition = _timelineDefinitions[currentTenseId];
  if (selectedDefinition == null) {
    return const <VerbTenseTimelineCardData>[];
  }

  final ids =
      _comparisonTenseIds[currentTenseId] ??
      _comparisonIdsForRegion(
        currentTenseId: currentTenseId,
        region: selectedDefinition.region,
      );

  return ids
      .take(3)
      .map((tenseId) {
        final definition = _timelineDefinitions[tenseId]!;
        return VerbTenseTimelineCardData(
          tenseId: tenseId,
          title: labels.titleFor(tenseId),
          region: definition.region,
          aspect: definition.aspect,
          isSelected: tenseId == currentTenseId,
        );
      })
      .toList(growable: false);
}

class _VerbTimelineDefinition {
  const _VerbTimelineDefinition({required this.region, required this.aspect});

  final VerbTimelineRegion region;
  final VerbTimelineAspect aspect;
}

const String _presentContinuousTenseId = 'presentContinuous';
const String _pastPerfectTenseId = 'pastPerfect';
const String _futureContinuousTenseId = 'futureContinuous';
const String _futurePerfectTenseId = 'futurePerfect';

const Map<String, _VerbTimelineDefinition> _timelineDefinitions =
    <String, _VerbTimelineDefinition>{
      VerbTenseIds.presentIndicative: _VerbTimelineDefinition(
        region: VerbTimelineRegion.present,
        aspect: VerbTimelineAspect.simple,
      ),
      VerbTenseIds.presentPerfect: _VerbTimelineDefinition(
        region: VerbTimelineRegion.present,
        aspect: VerbTimelineAspect.perfect,
      ),
      VerbTenseIds.preterite: _VerbTimelineDefinition(
        region: VerbTimelineRegion.past,
        aspect: VerbTimelineAspect.simple,
      ),
      VerbTenseIds.imperfectIndicative: _VerbTimelineDefinition(
        region: VerbTimelineRegion.past,
        aspect: VerbTimelineAspect.continuous,
      ),
      VerbTenseIds.futureSimple: _VerbTimelineDefinition(
        region: VerbTimelineRegion.future,
        aspect: VerbTimelineAspect.simple,
      ),
      VerbTenseIds.conditionalSimple: _VerbTimelineDefinition(
        region: VerbTimelineRegion.future,
        aspect: VerbTimelineAspect.simple,
      ),
      VerbTenseIds.presentSubjunctive: _VerbTimelineDefinition(
        region: VerbTimelineRegion.present,
        aspect: VerbTimelineAspect.simple,
      ),
      VerbTenseIds.imperfectSubjunctive: _VerbTimelineDefinition(
        region: VerbTimelineRegion.past,
        aspect: VerbTimelineAspect.continuous,
      ),
      _presentContinuousTenseId: _VerbTimelineDefinition(
        region: VerbTimelineRegion.present,
        aspect: VerbTimelineAspect.continuous,
      ),
      _pastPerfectTenseId: _VerbTimelineDefinition(
        region: VerbTimelineRegion.past,
        aspect: VerbTimelineAspect.perfect,
      ),
      _futureContinuousTenseId: _VerbTimelineDefinition(
        region: VerbTimelineRegion.future,
        aspect: VerbTimelineAspect.continuous,
      ),
      _futurePerfectTenseId: _VerbTimelineDefinition(
        region: VerbTimelineRegion.future,
        aspect: VerbTimelineAspect.perfect,
      ),
    };

const Map<String, List<String>> _comparisonTenseIds = <String, List<String>>{
  VerbTenseIds.presentIndicative: <String>[
    VerbTenseIds.presentIndicative,
    _presentContinuousTenseId,
    VerbTenseIds.presentPerfect,
  ],
  _presentContinuousTenseId: <String>[
    _presentContinuousTenseId,
    VerbTenseIds.presentIndicative,
    VerbTenseIds.presentPerfect,
  ],
  VerbTenseIds.presentPerfect: <String>[
    VerbTenseIds.presentPerfect,
    _presentContinuousTenseId,
    VerbTenseIds.presentIndicative,
  ],
  VerbTenseIds.preterite: <String>[
    VerbTenseIds.preterite,
    VerbTenseIds.imperfectIndicative,
    _pastPerfectTenseId,
  ],
  VerbTenseIds.imperfectIndicative: <String>[
    VerbTenseIds.imperfectIndicative,
    VerbTenseIds.preterite,
    _pastPerfectTenseId,
  ],
  _pastPerfectTenseId: <String>[
    _pastPerfectTenseId,
    VerbTenseIds.imperfectIndicative,
    VerbTenseIds.preterite,
  ],
  VerbTenseIds.futureSimple: <String>[
    VerbTenseIds.futureSimple,
    _futureContinuousTenseId,
    _futurePerfectTenseId,
  ],
  _futureContinuousTenseId: <String>[
    _futureContinuousTenseId,
    VerbTenseIds.futureSimple,
    _futurePerfectTenseId,
  ],
  _futurePerfectTenseId: <String>[
    _futurePerfectTenseId,
    _futureContinuousTenseId,
    VerbTenseIds.futureSimple,
  ],
  VerbTenseIds.conditionalSimple: <String>[
    VerbTenseIds.conditionalSimple,
    VerbTenseIds.futureSimple,
    _futurePerfectTenseId,
  ],
  VerbTenseIds.presentSubjunctive: <String>[
    VerbTenseIds.presentSubjunctive,
    VerbTenseIds.presentIndicative,
    VerbTenseIds.presentPerfect,
  ],
  VerbTenseIds.imperfectSubjunctive: <String>[
    VerbTenseIds.imperfectSubjunctive,
    VerbTenseIds.imperfectIndicative,
    VerbTenseIds.preterite,
  ],
};

List<String> _comparisonIdsForRegion({
  required String currentTenseId,
  required VerbTimelineRegion region,
}) {
  final currentAndSameRegion = <String>[
    currentTenseId,
    for (final entry in _timelineDefinitions.entries)
      if (entry.key != currentTenseId && entry.value.region == region)
        entry.key,
  ];
  return currentAndSameRegion.take(3).toList(growable: false);
}

class _VerbTenseTimelineCard extends StatelessWidget {
  const _VerbTenseTimelineCard({
    required this.data,
    required this.nowLabel,
    required this.compact,
  });

  final VerbTenseTimelineCardData data;
  final String nowLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = _regionColor(data.region);
    final titleStyle = Theme.of(context).textTheme.titleSmall?.copyWith(
      color: const Color(0xFF111827),
      fontSize: compact ? 13 : 16,
      fontWeight: FontWeight.w800,
      height: 1.06,
    );
    return Semantics(
      selected: data.isSelected,
      label: data.title,
      child: Container(
        padding: EdgeInsets.fromLTRB(10, compact ? 9 : 12, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: data.isSelected ? accent : const Color(0xFFD1D5DB),
            width: data.isSelected ? 3 : 1.5,
          ),
          boxShadow: [
            if (data.isSelected)
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              )
            else
              const BoxShadow(
                color: Color(0x12000000),
                blurRadius: 8,
                offset: Offset(0, 3),
              ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: compact ? 30 : 38,
              child: Center(
                child: Text(
                  data.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: titleStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            Expanded(
              child: CustomPaint(
                painter: _VerbTimelinePainter(
                  region: data.region,
                  aspect: data.aspect,
                  accent: accent,
                  nowLabel: nowLabel,
                  textDirection: Directionality.of(context),
                  compact: compact,
                ),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerbTimelinePainter extends CustomPainter {
  const _VerbTimelinePainter({
    required this.region,
    required this.aspect,
    required this.accent,
    required this.nowLabel,
    required this.textDirection,
    required this.compact,
  });

  final VerbTimelineRegion region;
  final VerbTimelineAspect aspect;
  final Color accent;
  final String nowLabel;
  final TextDirection textDirection;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final lineY = compact ? size.height * 0.34 : size.height * 0.36;
    final lineStart = size.width * 0.12;
    final lineEnd = size.width * 0.88;
    final nowX = size.width * 0.5;

    _drawArrowLine(
      canvas: canvas,
      start: Offset(lineStart, lineY),
      end: Offset(lineEnd, lineY),
    );
    _drawNowLine(
      canvas: canvas,
      x: nowX,
      top: math.max(0, lineY - 22),
      bottom: math.min(size.height - 18, lineY + 24),
    );
    _drawAspect(canvas, size, lineY);
    _drawNowLabel(canvas, size, lineY + (compact ? 25 : 29));
  }

  void _drawArrowLine({
    required Canvas canvas,
    required Offset start,
    required Offset end,
  }) {
    final paint = Paint()
      ..color = const Color(0xFF111827)
      ..strokeWidth = compact ? 2.4 : 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arrowSize = compact ? 9.0 : 12.0;
    final shaftEnd = Offset(end.dx - arrowSize, end.dy);
    canvas.drawLine(start, shaftEnd, paint);

    final arrowPath = Path()
      ..moveTo(shaftEnd.dx, shaftEnd.dy - arrowSize)
      ..lineTo(end.dx, end.dy)
      ..lineTo(shaftEnd.dx, shaftEnd.dy + arrowSize);
    canvas.drawPath(arrowPath, paint);
  }

  void _drawNowLine({
    required Canvas canvas,
    required double x,
    required double top,
    required double bottom,
  }) {
    final paint = Paint()
      ..color = const Color(0xFF8A8F98)
      ..strokeWidth = compact ? 2.4 : 3
      ..strokeCap = StrokeCap.round;
    const dash = 5.0;
    const gap = 5.0;
    var y = top;
    while (y < bottom) {
      final next = math.min(y + dash, bottom);
      canvas.drawLine(Offset(x, y), Offset(x, next), paint);
      y += dash + gap;
    }
  }

  void _drawAspect(Canvas canvas, Size size, double lineY) {
    switch (aspect) {
      case VerbTimelineAspect.simple:
        _drawSimpleMarker(canvas, size, lineY);
        break;
      case VerbTimelineAspect.continuous:
        _drawContinuousMarker(canvas, size, lineY);
        break;
      case VerbTimelineAspect.perfect:
        _drawPerfectMarker(canvas, size, lineY);
        break;
    }
  }

  void _drawSimpleMarker(Canvas canvas, Size size, double lineY) {
    final center = Offset(_pointX(size.width), lineY);
    final radius = compact ? 8.5 : 11.0;
    final paint = Paint()..color = accent;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawContinuousMarker(Canvas canvas, Size size, double lineY) {
    final (startFactor, endFactor) = switch (region) {
      VerbTimelineRegion.past => (0.18, 0.43),
      VerbTimelineRegion.present => (0.34, 0.66),
      VerbTimelineRegion.future => (0.57, 0.82),
    };
    final height = compact ? 11.0 : 13.0;
    final rect = Rect.fromLTRB(
      size.width * startFactor,
      lineY - (height / 2),
      size.width * endFactor,
      lineY + (height / 2),
    );
    final paint = Paint()..color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(height)),
      paint,
    );
  }

  void _drawPerfectMarker(Canvas canvas, Size size, double lineY) {
    final center = Offset(_pointX(size.width), lineY);
    final radius = compact ? 13.0 : 17.0;
    final circlePaint = Paint()..color = accent;
    canvas.drawCircle(center, radius, circlePaint);

    final checkPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = compact ? 3.2 : 4.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final check = Path()
      ..moveTo(center.dx - radius * 0.48, center.dy - radius * 0.02)
      ..lineTo(center.dx - radius * 0.14, center.dy + radius * 0.34)
      ..lineTo(center.dx + radius * 0.52, center.dy - radius * 0.42);
    canvas.drawPath(check, checkPaint);
  }

  void _drawNowLabel(Canvas canvas, Size size, double top) {
    final fontSize = compact ? 13.0 : 16.0;
    final painter = TextPainter(
      maxLines: 1,
      ellipsis: '...',
      text: TextSpan(
        text: nowLabel,
        style: TextStyle(
          color: const Color(0xFF111827),
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: textDirection,
    )..layout(maxWidth: size.width);
    final left = (size.width - painter.width) / 2;
    final safeTop = math.min(top, size.height - painter.height);
    painter.paint(canvas, Offset(left, safeTop));
  }

  double _pointX(double width) {
    final factor = switch (region) {
      VerbTimelineRegion.past => 0.25,
      VerbTimelineRegion.present => 0.5,
      VerbTimelineRegion.future => 0.75,
    };
    return width * factor;
  }

  @override
  bool shouldRepaint(covariant _VerbTimelinePainter oldDelegate) {
    return oldDelegate.region != region ||
        oldDelegate.aspect != aspect ||
        oldDelegate.accent != accent ||
        oldDelegate.nowLabel != nowLabel ||
        oldDelegate.textDirection != textDirection ||
        oldDelegate.compact != compact;
  }
}

Color _regionColor(VerbTimelineRegion region) {
  return switch (region) {
    VerbTimelineRegion.past => const Color(0xFF2563EB),
    VerbTimelineRegion.present => const Color(0xFF16A34A),
    VerbTimelineRegion.future => const Color(0xFFF97316),
  };
}

String _splitCamelCase(String value) {
  if (value.isEmpty) {
    return value;
  }
  final spaced = value.replaceAllMapped(
    RegExp(r'([a-z0-9])([A-Z])'),
    (match) => '${match.group(1)} ${match.group(2)}',
  );
  return spaced[0].toUpperCase() + spaced.substring(1);
}
