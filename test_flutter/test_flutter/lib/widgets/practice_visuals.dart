import 'package:flutter/material.dart';

import '../ui/app_style.dart';

/// Shared v7 visual components for recording and result pages.
/// Only presentation lives here; camera, analysis, and persistence stay in
/// their original screens and services.
class PracticeScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;

  const PracticeScreenHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            key: const Key('practice_back_button'),
            tooltip: '뒤로가기',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppStyle.ink),
          ),
          const SizedBox(width: 4),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppStyle.heading(size: 22)),
              if (subtitle != null) ...[
                const SizedBox(height: 3),
                Text(subtitle!, style: const TextStyle(
                  color: AppStyle.muted, fontSize: 12)),
              ],
            ],
          )),
        ],
      );
}

class PracticeSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;

  const PracticeSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(17),
    this.color = AppStyle.paper,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: AppStyle.card(color: color, radius: radius),
        child: child,
      );
}

class PracticeSectionTitle extends StatelessWidget {
  final String title;
  const PracticeSectionTitle(this.title, {super.key});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: AppStyle.heading(size: 17)),
      );
}

class PracticeTabs extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final List<String> labels;

  const PracticeTabs({
    super.key,
    required this.selected,
    required this.onSelected,
    this.labels = const ['요약', '음성', '입모양'],
  });

  @override
  Widget build(BuildContext context) => Material(
        color: AppStyle.paper,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: AppStyle.card(radius: 14),
          padding: const EdgeInsets.all(4),
          child: Row(children: [
            for (final item in labels)
              Expanded(child: InkWell(
                key: Key('practice_tab_$item'),
                onTap: () => onSelected(item),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == item
                        ? AppStyle.paleCoral : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: selected == item
                        ? Border.all(color: AppStyle.coral)
                        : null,
                  ),
                  child: Text(item, style: TextStyle(
                    color: selected == item
                        ? AppStyle.coral : AppStyle.muted,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  )),
                ),
              )),
          ]),
        ),
      );
}

class PracticeInfoRow extends StatelessWidget {
  final String title;
  final String value;
  const PracticeInfoRow({super.key, required this.title, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 4, child: Text(title,
            style: const TextStyle(color: AppStyle.muted,
                fontSize: 13, fontWeight: FontWeight.w600))),
          const SizedBox(width: 12),
          Expanded(flex: 5, child: Text(value,
            textAlign: TextAlign.right,
            softWrap: true,
            style: const TextStyle(color: AppStyle.ink,
                fontSize: 13, fontWeight: FontWeight.w700))),
        ]),
      );
}

class PracticeMetric extends StatelessWidget {
  final String title;
  final double score;
  final String label;
  const PracticeMetric({super.key,
    required this.title, required this.score, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        height: 124,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 12),
        decoration: AppStyle.card(color: AppStyle.paper, radius: 16),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, textAlign: TextAlign.center, maxLines: 2,
            style: const TextStyle(color: AppStyle.muted,
                fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 7),
          FittedBox(fit: BoxFit.scaleDown,
            child: Text(score.toStringAsFixed(1),
              style: const TextStyle(color: AppStyle.coral,
                fontWeight: FontWeight.w800, fontSize: 27))),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: AppStyle.muted,
            fontSize: 10)),
        ]),
      );
}
