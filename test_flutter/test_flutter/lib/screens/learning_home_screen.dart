import 'package:flutter/material.dart';
import '../ui/app_style.dart';

/// 학습 탭의 첫 화면: 자음·모음 학습과 추후 단어·문장 확장을 분리한다.
class LearningHomeScreen extends StatelessWidget {
  final ValueChanged<bool> onSelectPhonemes;

  const LearningHomeScreen({super.key, required this.onSelectPhonemes});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 23, 20, 30),
    children: [
      Text('발음 학습', style: AppStyle.heading(size: 28)),
      const SizedBox(height: 7),
      const Text('기초 발음부터 차근차근 연습해요.',
        style: TextStyle(color: AppStyle.muted, fontSize: 13)),
      const SizedBox(height: 27),
      Text('기초 발음', style: AppStyle.heading(size: 19)),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _PhonemeCategoryCard(
          letters: 'ㅏ ㅓ ㅗ', title: '모음 학습',
          subtitle: '혀의 위치와 입술 모양',
          background: AppStyle.paleCoral,
          onTap: () => onSelectPhonemes(false),
        )),
        const SizedBox(width: 12),
        Expanded(child: _PhonemeCategoryCard(
          letters: '가 나 다', title: '자음 학습',
          subtitle: '조음 위치와 방법 알아보기',
          background: AppStyle.paper,
          onTap: () => onSelectPhonemes(true),
        )),
      ]),
      const SizedBox(height: 29),
      Text('응용 발음', style: AppStyle.heading(size: 19)),
      const SizedBox(height: 12),
      const _ComingSoonTile(
        title: '단어 학습', subtitle: '배운 발음으로 단어 연습하기',
        icon: Icons.menu_book_outlined,
      ),
      const SizedBox(height: 10),
      const _ComingSoonTile(
        title: '문장 학습', subtitle: '일상생활 문장 발음 연습하기',
        icon: Icons.chat_bubble_outline_rounded,
      ),
      const SizedBox(height: 18),
      const Text('단어·문장 학습은 준비 중이에요.\n'
        '문장 발음 진단과 문장 학습은 서로 다른 기능이에요.',
        style: TextStyle(fontSize: 12, color: AppStyle.muted, height: 1.6)),
    ],
  );
}

class _PhonemeCategoryCard extends StatelessWidget {
  final String letters;
  final String title;
  final String subtitle;
  final Color background;
  final VoidCallback onTap;
  const _PhonemeCategoryCard({required this.letters, required this.title,
    required this.subtitle, required this.background, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        constraints: const BoxConstraints(minHeight: 177),
        decoration: BoxDecoration(
          border: Border.all(color: AppStyle.softBorder),
          borderRadius: BorderRadius.circular(17),
        ),
        padding: const EdgeInsets.all(15),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(letters, style: const TextStyle(
            color: AppStyle.coral, fontSize: 21, fontWeight: FontWeight.w900)),
          const SizedBox(height: 17),
          Text(title, style: const TextStyle(
            color: AppStyle.ink, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(subtitle, style: const TextStyle(
            color: AppStyle.muted, fontSize: 11, height: 1.4)),
          const SizedBox(height: 11),
          const Align(alignment: Alignment.centerRight,
            child: Icon(Icons.arrow_forward_rounded, color: AppStyle.coral)),
        ]),
      ),
    ),
  );
}

class _ComingSoonTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _ComingSoonTile({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 19),
    decoration: AppStyle.card(),
    child: Row(children: [
      Container(width: 46, height: 46,
        decoration: BoxDecoration(color: AppStyle.softInk,
          borderRadius: BorderRadius.circular(13)),
        child: Icon(icon, color: AppStyle.muted)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 15,
          fontWeight: FontWeight.w800, color: AppStyle.ink)),
        const SizedBox(height: 5),
        Text(subtitle, style: const TextStyle(fontSize: 11,
          color: AppStyle.muted)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(color: AppStyle.softInk,
          borderRadius: BorderRadius.circular(12)),
        child: const Text('준비 중', style: TextStyle(
          fontSize: 11, color: AppStyle.muted, fontWeight: FontWeight.w700)),
      ),
    ]),
  );
}
