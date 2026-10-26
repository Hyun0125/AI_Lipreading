import 'package:flutter/material.dart';

import '../ui/app_style.dart';

/// Two-stage navigation: learning category -> phoneme -> articulation details.
class PhonemePickerScreen extends StatelessWidget {
  final bool consonant;
  final ValueChanged<String> onSelect;

  const PhonemePickerScreen({
    super.key,
    required this.consonant,
    required this.onSelect,
  });

  static const consonants = <String, List<String>>{
    '입술소리 · 두입술': ['ㅂ', 'ㅃ', 'ㅍ', 'ㅁ'],
    '잇몸소리': ['ㄷ', 'ㄸ', 'ㅌ', 'ㄴ', 'ㄹ', 'ㅅ', 'ㅆ'],
    '센입천장소리': ['ㅈ', 'ㅉ', 'ㅊ'],
    '여린입천장소리': ['ㄱ', 'ㄲ', 'ㅋ', 'ㅇ'],
    '목청소리': ['ㅎ'],
  };
  static const vowels = <String, List<String>>{
    '단모음': ['ㅏ', 'ㅐ', 'ㅓ', 'ㅔ', 'ㅗ', 'ㅚ', 'ㅜ', 'ㅟ', 'ㅡ', 'ㅣ'],
    '이중모음': ['ㅑ', 'ㅒ', 'ㅕ', 'ㅖ', 'ㅘ', 'ㅙ', 'ㅛ', 'ㅝ', 'ㅞ', 'ㅠ', 'ㅢ'],
  };

  static const explanations = <String, String>{
    '입술소리 · 두입술': '두 입술을 붙이거나 가까이하여 만드는 소리',
    '잇몸소리': '혀끝과 윗잇몸 부근에서 만드는 소리',
    '센입천장소리': '혀 앞부분과 단단한 입천장에서 만드는 소리',
    '여린입천장소리': '혀 뒷부분과 부드러운 입천장에서 만드는 소리',
    '목청소리': '성문에서 공기 흐름을 조절해 만드는 소리',
    '단모음': '입모양이 비교적 일정하게 유지되는 소리',
    '이중모음': '발음 중 혀와 입술의 움직임이 달라지는 소리',
  };

  @override
  Widget build(BuildContext context) {
    final groups = consonant ? consonants : vowels;
    return Scaffold(
      backgroundColor: AppStyle.background,
      appBar: AppBar(title: Text(consonant ? '자음 학습' : '모음 학습')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 34),
        children: [
          Text(consonant ? '소리가 만들어지는 위치' : '혀와 입술의 움직임',
            style: AppStyle.heading(size: 23)),
          const SizedBox(height: 7),
          const Text('배우고 싶은 글자를 선택해 보세요.',
            style: TextStyle(fontSize: 13, color: AppStyle.muted)),
          const SizedBox(height: 23),
          for (final group in groups.entries) ...[
            Container(
              decoration: AppStyle.card(),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(group.key, style: AppStyle.heading(size: 17)),
                const SizedBox(height: 5),
                Text(explanations[group.key] ?? '',
                    style: const TextStyle(fontSize: 12, color: AppStyle.muted)),
                const SizedBox(height: 15),
                Wrap(spacing: 9, runSpacing: 9, children: [
                  for (final phoneme in group.value)
                    Semantics(
                      button: true,
                      label: '$phoneme 발음 학습',
                      child: OutlinedButton(
                        key: Key('phoneme_$phoneme'),
                        onPressed: () => onSelect(phoneme),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(51, 50),
                          foregroundColor: AppStyle.ink,
                          backgroundColor: AppStyle.paleCoral,
                          side: const BorderSide(color: AppStyle.softBorder),
                        ),
                        child: Text(phoneme, style: const TextStyle(
                          fontSize: 21, fontWeight: FontWeight.w800)),
                      ),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          const Text('자음은 ‘가’처럼 모음을 결합한 음절로 발음 연습을 진행해요. '
            '조음 그림은 학습을 돕는 자료이며 전문가 검수가 필요한 부분이 있어요.',
            style: TextStyle(fontSize: 11, height: 1.55, color: AppStyle.muted)),
        ],
      ),
    );
  }
}
