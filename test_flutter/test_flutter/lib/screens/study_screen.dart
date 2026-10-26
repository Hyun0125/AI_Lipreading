import 'package:flutter/material.dart';

import '../data/pronunciation_image_data.dart';
import '../data/study_data.dart';
import '../ui/app_style.dart';
import 'feedback_screen.dart';

/// Detailed pronunciation teaching content — accessible from catalog.
class StudyScreen extends StatefulWidget {
  final String item;
  final String category;
  const StudyScreen({super.key, required this.item, required this.category});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  int _tab = 0;

  static const _practiceSyllables = <String, String>{
    'ㄱ': '가', 'ㄲ': '까', 'ㅋ': '카', 'ㅇ': '아',
    'ㄴ': '나', 'ㄷ': '다', 'ㄸ': '따', 'ㅌ': '타', 'ㄹ': '라',
    'ㅂ': '바', 'ㅃ': '빠', 'ㅍ': '파', 'ㅁ': '마',
    'ㅅ': '사', 'ㅆ': '싸', 'ㅈ': '자', 'ㅉ': '짜',
    'ㅊ': '차', 'ㅎ': '하',
  };

  @override
  Widget build(BuildContext context) {
    final data = getStudyData(widget.item);
    final image = pronunciationImagePaths[widget.item];
    final syllable = widget.category == '자음'
      ? (_practiceSyllables[widget.item] ?? widget.item)
      : widget.item;

    return Scaffold(
      appBar: AppBar(title: Text('${widget.item} 발음 방법')),
      body: SafeArea(child: Column(children: [
        Expanded(child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          children: [
            Text('${widget.item} 발음 익히기',
              style: AppStyle.heading(size: 27)),
            const SizedBox(height: 7),
            Text('발음 연습 목표: $syllable', style: const TextStyle(
              fontWeight: FontWeight.w700, color: AppStyle.coral)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _TabPill(title: '발음 설명', active: _tab == 0,
                onTap: () => setState(() => _tab = 0))),
              const SizedBox(width: 10),
              Expanded(child: _TabPill(title: '입모양 자료', active: _tab == 1,
                onTap: () => setState(() => _tab = 1))),
            ]),
            const SizedBox(height: 16),
            if (_tab == 0) ...[
              _InfoPanel(title: data.title, content: data.description),
              const SizedBox(height: 13),
              _InfoPanel(title: data.methodTitle, content: data.method),
              const SizedBox(height: 13),
              _InfoPanel(title: '연습 도움말', content: data.tip,
                highlight: true),
            ] else ...[
              Container(
                decoration: AppStyle.card(),
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$syllable 입모양 관찰', style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 13),
                  if (image == null)
                    const SizedBox(height: 205,
                      child: Center(child: Text('발음 이미지 준비 중')))
                  else
                    Image.asset(image,
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: 280,
                      semanticLabel: '${widget.item} 발음 기준 입모양',
                      errorBuilder: (_, _, _) => const SizedBox(height: 200,
                        child: Center(child: Text('이미지를 표시할 수 없어요'))),
                    ),
                  const SizedBox(height: 11),
                  const Text('표준 입모양은 참고 자료예요. 실제 조음 위치와 개인별 차이는 '
                      '설명과 함께 확인해 주세요.',
                    style: TextStyle(fontSize: 12,
                      color: AppStyle.muted, height: 1.55)),
                ]),
              ),
            ],
            const SizedBox(height: 16),
            if (widget.category == '자음')
              const Text('자음은 모음 ‘ㅏ’를 붙여 발음 가능한 음절로 연습해요.',
                style: TextStyle(fontSize: 12, color: AppStyle.muted)),
          ],
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => FeedbackScreen(item: widget.item,
                category: widget.category))),
            icon: const Icon(Icons.mic_none_rounded),
            label: Text('$syllable 발음 연습하기'),
          )),
        ),
      ])),
    );
  }
}

class _TabPill extends StatelessWidget {
  final String title;
  final bool active;
  final VoidCallback onTap;
  const _TabPill({required this.title, required this.active,
    required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      foregroundColor: active ? AppStyle.coral : AppStyle.muted,
      backgroundColor: active ? AppStyle.paleCoral : Colors.white,
      side: BorderSide(color: active ? AppStyle.coral : AppStyle.softBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      minimumSize: const Size.fromHeight(45),
    ),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

class _InfoPanel extends StatelessWidget {
  final String title;
  final String content;
  final bool highlight;
  const _InfoPanel({required this.title, required this.content,
    this.highlight = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: AppStyle.card(color: highlight ? AppStyle.paleCoral
      : AppStyle.paper),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
        fontSize: 17, fontWeight: FontWeight.w800, color: AppStyle.ink)),
      const SizedBox(height: 12),
      Text(content, style: const TextStyle(fontSize: 14,
        height: 1.65, color: AppStyle.ink)),
    ]),
  );
}
