import 'package:flutter/material.dart';
import 'data/study_data.dart';
import 'screens/feedback_screen.dart';
import 'screens/review_screen.dart';

void main() {
  runApp(const MyApp());
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedCategory = '자음';
  String selectedMode = '학습';
  String selectedItem = '';

  bool get isItemSelected => selectedItem.isNotEmpty;

  void cancelItemSelection() {
    setState(() {
      selectedItem = '';
      selectedMode = '학습';
    });
  }

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
          borderRadius: isLongButton
              ? BorderRadius.circular(35)
              : null,
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

  Widget itemRow(List<String> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.map((e) => buildCircleButton(e)).toList(),
      ),
    );
  }

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
            border: isItemSelected
                ? Border.all(color: Colors.grey[300]!)
                : null,
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

/// 공부하기 화면
class StudyScreen extends StatefulWidget {
  final String item;
  final String category;

  const StudyScreen({
    super.key,
    required this.item,
    required this.category,
  });

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  String selectedTab = '이론';



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

  Widget imageOrVideoContent(String label) {
    return Center(
      child: Text(
        "${widget.item} $label 자료가 들어갈 영역입니다.",
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
      content = imageOrVideoContent('사진');
    } else if (selectedTab == '영상') {
      content = imageOrVideoContent('영상');
    } else {
      content = theoryContent();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children:[
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
          ),),
          closeButton(context),
          ],
        ),
      ),
    );
  }
}

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