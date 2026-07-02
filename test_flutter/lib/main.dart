import 'package:flutter/material.dart';

import 'screens/feedback_screen.dart';
import 'screens/review_screen.dart';
import 'screens/study_screen.dart';

// 앱 실행 시작점
// MyApp을 실행하여 전체 Flutter 앱을 시작한다.
void main() {
  runApp(const MyApp());
}

// 앱의 최상위 위젯
// MaterialApp을 생성하고 첫 화면으로 HomeScreen을 보여준다.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

// 학습모드 메인 화면
// 자음, 모음, 단어, 문장 항목을 선택하고 공부하기 또는 피드백받기로 이동하는 화면
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = '자음'; // 현재 선택된 학습 종류
  String selectedMode = '학습'; // 현재 선택된 하단 모드
  String selectedItem = ''; // 현재 선택된 학습 항목

  bool get isItemSelected => selectedItem.isNotEmpty; // 항목이 선택된 상태인지 확인하는 getter

  // 선택된 항목을 취소하는 함수
  // 회색 배경 상태를 해제하고 학습모드 기본 상태로 되돌린다.
  void cancelItemSelection() {
    setState(() {
      selectedItem = '';
      selectedMode = '학습';
    });
  }

  // 공부하기 화면으로 이동하는 함수
  // 선택된 항목이 없으면 이동하지 않는다.
  void goToStudyScreen() {
    if (!isItemSelected) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => StudyScreen(
          item: selectedItem,
          category: selectedCategory,
        ),
      ),
    );
  }

  // 피드백받기 화면으로 이동하는 함수
  // 선택된 항목이 없으면 이동하지 않는다.
  void goToFeedbackScreen() {
    if (!isItemSelected) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FeedbackScreen(
          item: selectedItem,
          category: selectedCategory,
        ),
      ),
    );
  }

  // 상단 카테고리 버튼 위젯
  // 자음, 모음, 단어, 문장 버튼을 만들 때 사용한다.
  Widget buildCategoryButton(
      String text,
      String selectedValue,
      Function(String) onTap,
      ) {
    final isSelected = text == selectedValue;

    return GestureDetector(
      onTap: () => onTap(text),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[200],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // 학습 항목 버튼 위젯
  // 자음과 모음은 원형 버튼, 단어와 문장은 긴 버튼 형태로 보여준다.
  Widget buildCircleButton(String text) {
    final isSelected = text == selectedItem;

    final bool isLongButton =
        selectedCategory == '단어' || selectedCategory == '문장';

    final double buttonWidth = selectedCategory == '문장'
        ? 150
        : selectedCategory == '단어'
        ? 120
        : 70;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedItem = text;
          selectedMode = '';
        });
      },
      child: Container(
        width: buttonWidth,
        height: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.grey[200],
          borderRadius: isLongButton ? BorderRadius.circular(35) : null,
          shape: isLongButton ? BoxShape.rectangle : BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isLongButton ? 12 : 0,
          ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // 주제가 어떤 소리인지를 기준으로 묶은 제목 위젯
  Widget sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  // 항목 버튼들을 가로 스크롤로 보여주는 위젯
  Widget itemRow(List<String> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.map((e) => buildCircleButton(e)).toList(),
      ),
    );
  }

  // 선택한 카테고리에 따라 항목 목록을 구성하는 함수
  // 자음, 모음, 단어, 문장별로 다른 항목 목록을 보여준다.
  Widget buildCategoryContent() {
    if (selectedCategory == '모음') {
      return ListView(
        children: [
          sectionTitle('단모음'),
          itemRow(['ㅏ', 'ㅓ', 'ㅗ', 'ㅜ', 'ㅡ', 'ㅣ']),
          sectionTitle('이중모음'),
          itemRow(['ㅑ', 'ㅕ', 'ㅛ', 'ㅠ', 'ㅐ', 'ㅔ']),
          sectionTitle('복합모음'),
          itemRow(['ㅒ', 'ㅖ', 'ㅘ', 'ㅙ', 'ㅝ', 'ㅞ', 'ㅚ', 'ㅟ', 'ㅢ']),
        ],
      );
    }

    if (selectedCategory == '단어') {
      return ListView(
        children: [
          sectionTitle('기초 단어'),
          itemRow(['가방', '나무', '다리', '마음']),
          sectionTitle('일상 단어'),
          itemRow(['학교', '사과', '우유', '친구']),
        ],
      );
    }

    if (selectedCategory == '문장') {
      return ListView(
        children: [
          sectionTitle('기초 문장'),
          itemRow(['안녕', '고마워']),
          sectionTitle('일상 문장'),
          itemRow(['학교에 가요', '밥 먹었어요']),
        ],
      );
    }

    return ListView(
      children: [
        sectionTitle('여린입천장소리'),
        itemRow(['ㄱ', 'ㄲ', 'ㅋ', 'ㅇ']),
        sectionTitle('두입술소리'),
        itemRow(['ㅂ', 'ㅃ', 'ㅍ', 'ㅁ']),
        sectionTitle('잇몸소리'),
        itemRow(['ㄷ', 'ㄸ', 'ㅌ', 'ㅅ', 'ㅆ', 'ㄴ', 'ㄹ']),
        sectionTitle('센입천장소리'),
        itemRow(['ㅈ', 'ㅉ', 'ㅊ']),
        sectionTitle('목청소리'),
        itemRow(['ㅎ']),
      ],
    );
  }

  // 하단 모드 버튼 위젯
  // 학습/복습 또는 공부하기/피드백받기 버튼을 만들 때 사용한다.
  Widget bottomButton({
    required String text,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isItemSelected
                ? (isSelected ? Colors.black : Colors.white)
                : (isSelected ? Colors.black : Colors.grey[300]),
            borderRadius: BorderRadius.circular(10),
            border: isItemSelected ? Border.all(color: Colors.grey[300]!) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  // 화면 하단의 버튼 영역
  // 항목 선택 전에는 학습/복습, 항목 선택 후에는 공부하기/피드백받기를 보여준다.
  Widget bottomButtonArea() {
    final bool isStudyButtonSelected =
        selectedMode == '학습' || selectedMode == '공부하기';

    final bool isReviewButtonSelected =
        selectedMode == '복습' || selectedMode == '피드백받기';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: Row(
        children: [
          bottomButton(
            text: isItemSelected ? '공부하기' : '학습',
            isSelected: isStudyButtonSelected,
            onTap: () {
              if (isItemSelected) {
                setState(() {
                  selectedMode = '공부하기';
                });

                goToStudyScreen();
              } else {
                setState(() {
                  selectedMode = '학습';
                });
              }
            },
          ),
          const SizedBox(width: 10),
          bottomButton(
            text: isItemSelected ? '피드백받기' : '복습',
            isSelected: isReviewButtonSelected,
            onTap: () async {
              if (isItemSelected) {
                setState(() {
                  selectedMode = '피드백받기';
                });

                goToFeedbackScreen();
              } else {
                setState(() {
                  selectedMode = '복습';
                });

                await Navigator.push(
                  context,
                  PageRouteBuilder(
                    transitionDuration: Duration.zero,
                    reverseTransitionDuration: Duration.zero,
                    pageBuilder: (context, animation, secondaryAnimation) =>
                    const ReviewScreen(),
                  ),
                );

                if (!mounted) return;

                setState(() {
                  selectedMode = '학습';
                });
              }
            },
          ),
        ],
      ),
    );
  }

  // 학습모드의 메인 화면 영역
  // 카테고리 버튼, 항목 버튼 목록, 선택 취소용 회색 배경을 관리한다.
  Widget mainContentArea() {
    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (isItemSelected) {
              cancelItemSelection();
            }
          },
          child: Container(
            color: isItemSelected ? Colors.grey[300] : Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const Text(
                    '학습모드',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildCategoryButton('자음', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '학습';
                        });
                      }),
                      const SizedBox(width: 8),
                      buildCategoryButton('모음', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '학습';
                        });
                      }),
                      const SizedBox(width: 8),
                      buildCategoryButton('단어', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '학습';
                        });
                      }),
                      const SizedBox(width: 8),
                      buildCategoryButton('문장', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '학습';
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    child: buildCategoryContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (isItemSelected)
          Positioned(
            top: 6,
            right: 10,
            child: GestureDetector(
              onTap: cancelItemSelection,
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
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: mainContentArea(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: bottomButtonArea(),
            ),
          ],
        ),
      ),
    );
  }
}