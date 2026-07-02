import 'package:flutter/material.dart';

import '../data/study_data.dart';
import '../data/pronunciation_image_data.dart';

/// 공부하기 화면
class StudyScreen extends StatefulWidget {
  final String item; // 선택한 학습 주제
  final String category; // 선택한 학습 종류

  const StudyScreen({
    super.key,
    required this.item,
    required this.category,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  String selectedTab = '이론'; // 현재 선택된 탭

  // 상단 탭 버튼 위젯
  // 이론, 사진, 영상 탭을 전환하는 데 사용한다.
  Widget tabButton(String text) {
    final isSelected = selectedTab == text;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedTab = text;
        });
      },
      child: Column(
        children: [
          Text(
            text,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.black : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 28,
            height: 2,
            color: isSelected ? Colors.black : Colors.transparent,
          ),
        ],
      ),
    );
  }

  // 회색 배경의 작은 제목 위젯
  // 학습 설명, 발음 방법, 도움말 같은 섹션 제목에 사용한다.
  Widget pillTitle(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 자음에 모음 'ㅏ'를 붙였을 때의 발음 형태를 반환한다.
  // 예: ㄱ -> 가, ㄴ -> 나
  String consonantPracticeText(String item) {
    const Map<String, String> practiceTextMap = {
      'ㄱ': '가',
      'ㄲ': '까',
      'ㅋ': '카',
      'ㅇ': '아',
      'ㄴ': '나',
      'ㄷ': '다',
      'ㄸ': '따',
      'ㅌ': '타',
      'ㄹ': '라',
      'ㅂ': '바',
      'ㅃ': '빠',
      'ㅍ': '파',
      'ㅁ': '마',
      'ㅅ': '사',
      'ㅆ': '싸',
      'ㅈ': '자',
      'ㅉ': '짜',
      'ㅊ': '차',
      'ㅎ': '하',
    };

    return practiceTextMap[item] ?? item;
  }

  // 이론 탭 화면
  // study_data.dart에서 선택한 항목의 설명, 발음 방법, 도움말을 가져와 보여준다.
  Widget theoryContent() {
    final data = getStudyData(widget.item);

    return ListView(
      children: [
        pillTitle(data.title),
        const SizedBox(height: 18),
        Text(
          data.description,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        pillTitle(data.methodTitle),
        const SizedBox(height: 18),
        Text(
          data.method,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        pillTitle('도움말'),
        const SizedBox(height: 18),
        Text(
          data.tip,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // 사진 탭 화면
  // 선택한 자음 또는 모음에 해당하는 발음 사진 자료를 보여준다.
  Widget photoContent() {
    final imagePath = pronunciationImagePaths[widget.item];
    final isConsonant = widget.category == '자음';
    final practiceText = consonantPracticeText(widget.item);

    if (imagePath == null) {
      return ListView(
        children: [
          pillTitle('${widget.item} 발음 사진'),
          const SizedBox(height: 18),
          Text(
            '${widget.item} 사진 자료가 아직 등록되지 않았습니다.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      );
    }

    return ListView(
      children: [
        pillTitle('${widget.item} 발음 사진'),
        const SizedBox(height: 18),

        if (isConsonant) ...[
          Text(
            "자음은 입모양과 음성을 더 정확히 분석하기 위해 모음 'ㅏ'를 붙인 형태로 연습합니다.\n"
                "예: ${widget.item} → $practiceText",
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
        ],

        Container(
          width: double.infinity,
          height: 320,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Image.asset(
            imagePath,
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: 24),

        pillTitle('연습 방법'),
        const SizedBox(height: 18),
        Text(
          isConsonant
              ? "'$practiceText' 입모양을 보고 따라 발음해 보세요."
              : "'${widget.item}' 입모양을 보고 따라 발음해 보세요.",
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  // 영상 탭 화면
  // 추후 자음, 모음, 단어, 문장별 영상 자료를 넣을 위치
  Widget videoContent() {
    return Center(
      child: Text(
        "${widget.item} 영상 자료가 들어갈 영역입니다.",
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (selectedTab == '사진') {
      content = photoContent();
    } else if (selectedTab == '영상') {
      content = videoContent();
    } else {
      content = theoryContent();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
              child: Column(
                children: [
                  const Text(
                    '학습모드 - 공부하기',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      tabButton('이론'),
                      const SizedBox(width: 34),
                      tabButton('사진'),
                      const SizedBox(width: 34),
                      tabButton('영상'),
                    ],
                  ),
                  const SizedBox(height: 26),
                  Expanded(
                    child: content,
                  ),
                ],
              ),
            ),
            closeButton(context),
          ],
        ),
      ),
    );
  }
}

// 닫기 버튼 위젯
// 현재 화면을 종료하고 이전 화면으로 돌아가는 X 버튼
Widget closeButton(BuildContext context) {
  return Positioned(
    top: 6,
    right: 10,
    child: GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Icon(
          Icons.close,
          size: 30,
          color: Colors.black,
        ),
      ),
    ),
  );
}