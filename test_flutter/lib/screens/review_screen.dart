import 'package:flutter/material.dart';

import '../models/feedback_result.dart';
import '../services/feedback_api.dart';
import 'review_result_detail_screen.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String selectedCategory = '자음';
  String selectedMode = '복습';
  String selectedItem = '';

  Set<String> enabledItemKeys = {};
  bool isLoadingEnabledItems = true;

  bool get isItemSelected => selectedItem.isNotEmpty;

  @override
  void initState() {
    super.initState();
    loadEnabledItems();
  }

  String makeItemKey(String category, String item) {
    return '$category|$item';
  }

  Future<void> loadEnabledItems() async {
    try {
      final results = await FeedbackApi.getAllReviewResults();

      final keys = results.map((result) {
        return makeItemKey(result.category, result.targetItem);
      }).toSet();

      if (!mounted) return;

      setState(() {
        enabledItemKeys = keys;
        isLoadingEnabledItems = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingEnabledItems = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('복습 항목 조회 중 오류가 발생했습니다: $e'),
        ),
      );
    }
  }

  bool isEnabledItem(String item) {
    return enabledItemKeys.contains(
      makeItemKey(selectedCategory, item),
    );
  }

  void cancelItemSelection() {
    setState(() {
      selectedItem = '';
      selectedMode = '복습';
    });
  }

  String formatDate(String createdAt) {
    if (createdAt.length >= 16) {
      return createdAt.substring(0, 16);
    }
    return createdAt;
  }

  Future<void> openReviewResult(String item) async {
    if (!isEnabledItem(item)) return;

    setState(() {
      selectedItem = item;
    });

    try {
      final results = await FeedbackApi.getReviewResults(
        category: selectedCategory,
        targetItem: item,
      );

      if (!mounted) return;

      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('저장된 피드백 기록이 없습니다.'),
          ),
        );
        return;
      }

      showReviewRecordPopup(
        targetItem: item,
        results: results,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('복습 기록 조회 중 오류가 발생했습니다: $e'),
        ),
      );
    }
  }

  void showReviewRecordPopup({
    required String targetItem,
    required List<FeedbackResult> results,
  }) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: SizedBox(
            width: 300,
            height: 360,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$targetItem 피드백 기록',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(dialogContext);
                        },
                        child: const Icon(
                          Icons.close,
                          size: 24,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Expanded(
                    child: ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (context, index) {
                        return const SizedBox(height: 14);
                      },
                      itemBuilder: (context, index) {
                        final result = results[index];

                        return GestureDetector(
                          onTap: () {
                            Navigator.pop(dialogContext);

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ReviewResultDetailScreen(
                                      result: result,
                                    ),
                              ),
                            );
                          },
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  color: Colors.black,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '${results.length - index}번',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${results.length - index}번 연습',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      formatDate(result.createdAt),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const Icon(
                                Icons.chevron_right,
                                size: 26,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    final isEnabled = isEnabledItem(text);

    final bool isLongButton =
        selectedCategory == '단어' || selectedCategory == '문장';

    final double buttonWidth = selectedCategory == '문장'
        ? 150
        : selectedCategory == '단어'
        ? 120
        : 70;

    return GestureDetector(
      onTap: isEnabled ? () => openReviewResult(text) : null,
      child: Container(
        width: buttonWidth,
        height: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isEnabled
              ? (isSelected ? Colors.black : Colors.grey[200])
              : Colors.grey[100],
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
              fontSize: isLongButton ? 17 : 24,
              fontWeight: FontWeight.bold,
              color: isEnabled
                  ? (isSelected ? Colors.white : Colors.black)
                  : Colors.grey[400],
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
    final bool isStudyButtonSelected = selectedMode == '학습';
    final bool isReviewButtonSelected = selectedMode == '복습';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: Row(
        children: [
          bottomButton(
            text: '학습',
            isSelected: isStudyButtonSelected,
            onTap: () async {
              setState(() {
                selectedMode = '학습';
              });

              await Future.delayed(
                const Duration(milliseconds: 10),
              );

              if (!mounted) return;

              Navigator.pop(context);
            },
          ),
          const SizedBox(width: 10),
          bottomButton(
            text: '복습',
            isSelected: isReviewButtonSelected,
            onTap: () {
              setState(() {
                selectedMode = '복습';
              });
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
                    '복습모드',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 25,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      buildCategoryButton('자음', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '복습';
                        });
                      }),
                      const SizedBox(width: 8),
                      buildCategoryButton('모음', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '복습';
                        });
                      }),
                      const SizedBox(width: 8),
                      buildCategoryButton('단어', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '복습';
                        });
                      }),
                      const SizedBox(width: 8),
                      buildCategoryButton('문장', selectedCategory, (val) {
                        setState(() {
                          selectedCategory = val;
                          selectedItem = '';
                          selectedMode = '복습';
                        });
                      }),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Expanded(
                    child: isLoadingEnabledItems
                        ? const Center(
                      child: CircularProgressIndicator(),
                    )
                        : buildCategoryContent(),
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