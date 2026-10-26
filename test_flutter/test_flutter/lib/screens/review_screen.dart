import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../models/feedback_result.dart';
import '../services/feedback_api.dart';
import 'review_result_detail_screen.dart';

// 복습모드 화면
// DB에 저장된 피드백 기록이 있는 항목만 활성화하고, 선택한 항목의 복습 기록을 조회한다.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key});

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  String selectedCategory = '자음'; // 현재 선택된 학습 종류
  String selectedMode = '복습'; // 현재 선택된 하단 모드
  String selectedItem = ''; // 현재 선택된 학습 항목

  Set<String> enabledItemKeys = {}; // 저장된 피드백 기록이 있는 항목 key 목록
  bool isLoadingEnabledItems = true; // 복습 가능 항목을 불러오는 중인지 여부

  bool get isItemSelected => selectedItem.isNotEmpty; // 항목이 선택된 상태인지 확인하는 getter

  @override
  void initState() {
    super.initState();
    loadEnabledItems();
  }

  // category와 item을 하나의 key로 만드는 함수
  String makeItemKey(String category, String item) {
    return '$category|$item';
  }

  // 복습 가능한 항목 목록을 불러오는 함수
  // 저장된 피드백 기록이 있는 항목만 enabledItemKeys에 저장한다.
  Future<void> loadEnabledItems() async {
    try {
      final results = await FeedbackApi.getAllReviewResults(
        userId: AppConfig.currentUserId,
      );

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

  // 현재 선택된 category에서 item이 복습 가능한 항목인지 확인하는 함수
  bool isEnabledItem(String item) {
    return enabledItemKeys.contains(
      makeItemKey(selectedCategory, item),
    );
  }

  // 선택된 항목을 취소하는 함수
  // 회색 배경 상태를 해제하고 복습모드 기본 상태로 되돌린다.
  void cancelItemSelection() {
    setState(() {
      selectedItem = '';
      selectedMode = '복습';
    });
  }

  // 저장 날짜 표시 형식을 정리하는 함수
  // createdAt이 길면 년-월-일 시:분까지만 표시한다.
  String formatDate(String createdAt) {
    if (createdAt.length >= 16) {
      return createdAt.substring(0, 16);
    }
    return createdAt;
  }

  // 점수를 정수 형태로 표시하는 함수
  String formatScore(double score) {
    return score.round().toString();
  }

  // 종합, 음성, 입모양 중 선택된 점수 값을 반환하는 함수
  double getScoreByType(FeedbackResult result, String scoreType) {
    if (scoreType == '음성 점수') {
      return result.audioTotalScore;
    }

    if (scoreType == '입모양 점수') {
      return result.visualTotalScore;
    }

    return (result.audioTotalScore + result.visualTotalScore) / 2;
  }

  // createdAt 기준으로 오래된 기록부터 정렬하는 함수
  // 그래프의 x축을 1번, 2번, 3번 순서로 보여주기 위해 사용한다.
  List<FeedbackResult> sortResultsByDate(List<FeedbackResult> results) {
    final sortedResults = [...results];

    sortedResults.sort((a, b) {
      return a.createdAt.compareTo(b.createdAt);
    });

    return sortedResults;
  }

  // 선택한 항목의 복습 기록을 여는 함수
  // 복습 가능한 항목일 때만 서버에서 기록을 조회한다.
  Future<void> openReviewResult(String item) async {
    if (!isEnabledItem(item)) return;

    setState(() {
      selectedItem = item;
    });

    try {
      final results = await FeedbackApi.getReviewResults(
        category: selectedCategory,
        targetItem: item,
        userId: AppConfig.currentUserId,
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

  // 그래프 상단 점수 탭 버튼 위젯
  Widget scoreTypeButton({
    required String text,
    required String selectedScoreType,
    required VoidCallback onTap,
  }) {
    final bool isSelected = selectedScoreType == text;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  // 선택한 점수의 직전 기록 대비 변화량을 구하는 함수
  double? getScoreDiff({
    required List<FeedbackResult> sortedResults,
    required int selectedIndex,
    required String scoreType,
  }) {
    if (selectedIndex <= 0) {
      return null;
    }

    final currentScore = getScoreByType(
      sortedResults[selectedIndex],
      scoreType,
    );

    final previousScore = getScoreByType(
      sortedResults[selectedIndex - 1],
      scoreType,
    );

    return currentScore - previousScore;
  }

  // 그래프 tooltip 문구를 만드는 함수
  String makeTooltipText({
    required List<FeedbackResult> sortedResults,
    required int selectedIndex,
    required String scoreType,
  }) {
    final currentScore = getScoreByType(
      sortedResults[selectedIndex],
      scoreType,
    );

    final diff = getScoreDiff(
      sortedResults: sortedResults,
      selectedIndex: selectedIndex,
      scoreType: scoreType,
    );

    if (diff == null) {
      return '${formatScore(currentScore)}점';
    }

    final diffText = diff >= 0
        ? '+${diff.round()}'
        : diff.round().toString();

    return '${formatScore(currentScore)}점 ($diffText)';
  }

  // 그래프 위젯
  // 각 점을 클릭하면 해당 연습의 점수와 직전 대비 점수차를 tooltip으로 보여준다.
  Widget scoreTrendChart({
    required List<FeedbackResult> sortedResults,
    required String scoreType,
    required int selectedPointIndex,
    required Function(int) onPointTap,
  }) {
    final spots = <FlSpot>[];

    for (int i = 0; i < sortedResults.length; i++) {
      final score = getScoreByType(
        sortedResults[i],
        scoreType,
      );

      spots.add(
        FlSpot(
          i.toDouble(),
          score.clamp(0, 100).toDouble(),
        ),
      );
    }

    final selectedSpot = spots[selectedPointIndex];

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          minX: -0.5,
          maxX: sortedResults.length - 0.5,
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 20,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey[300],
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
              bottom: BorderSide(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 20,
                reservedSize: 38,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) {
                    return const SizedBox.shrink();
                  }

                  final index = value.toInt();

                  if (index < 0 || index >= sortedResults.length) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${index + 1}번',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                },              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;
              if (response == null || response.lineBarSpots == null) return;
              if (response.lineBarSpots!.isEmpty) return;

              final index = response.lineBarSpots!.first.spotIndex;
              onPointTap(index);
            },
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: Colors.grey[600],
                    strokeWidth: 1,
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.grey[800]!,
                        strokeWidth: 3,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipColor: (touchedSpot) {
                return Colors.white;
              },
              tooltipRoundedRadius: 8,
              tooltipBorder: BorderSide(
                color: Colors.grey[400]!,
                width: 1,
              ),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final index = touchedSpot.spotIndex;
                  final currentScore = getScoreByType(
                    sortedResults[index],
                    scoreType,
                  );

                  final diff = getScoreDiff(
                    sortedResults: sortedResults,
                    selectedIndex: index,
                    scoreType: scoreType,
                  );

                  if (diff == null) {
                    return LineTooltipItem(
                      '${formatScore(currentScore)}점',
                      const TextStyle(
                        color: Colors.black,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }

                  final diffText = diff >= 0
                      ? '+${diff.round()}'
                      : diff.round().toString();

                  final arrowText = diff >= 0 ? '▲' : '▼';

                  return LineTooltipItem(
                    '${formatScore(currentScore)}점 ($diffText',
                    const TextStyle(
                      color: Colors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    children: [
                      TextSpan(
                        text: arrowText,
                        style: TextStyle(
                          color: diff >= 0 ? Colors.red : Colors.blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(
                        text: ')',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  );
                }).toList();
              },
            ),
          ),
          showingTooltipIndicators: [
            ShowingTooltipIndicators([
              LineBarSpot(
                LineChartBarData(
                  spots: spots,
                ),
                0,
                selectedSpot,
              ),
            ]),
          ],
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 3,
              color: Colors.grey[800],
              belowBarData: BarAreaData(show: false),
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final bool isSelected = index == selectedPointIndex;

                  return FlDotCirclePainter(
                    radius: isSelected ? 7 : 5,
                    color: Colors.grey[800]!,
                    strokeWidth: isSelected ? 4 : 0,
                    strokeColor: isSelected ? Colors.grey[300]! : Colors.transparent,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 복습 기록 카드 위젯
  // 각 연습 기록을 클릭하면 상세 화면으로 이동한다.
  Widget reviewRecordCard({
    required BuildContext dialogContext,
    required FeedbackResult result,
    required int practiceNumber,
    required double score,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          dialogContext,
          MaterialPageRoute(
            builder: (context) => ReviewResultDetailScreen(
              result: result,
            ),
          ),
        );
      },
      child: Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.grey[300]!,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$practiceNumber번',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(width: 16),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$practiceNumber번 연습',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
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

            Text(
              '${formatScore(score)}점',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(width: 8),

            const Icon(
              Icons.chevron_right,
              size: 30,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  // 복습 기록 목록 팝업을 보여주는 함수
  // 그래프와 날짜별 연습 기록을 함께 보여준다.
  //
  // 기록이 적을 때는 굳이 그래프 영역에서 스크롤되지 않도록 막고,
  // 기록이 많을 때만 그래프 영역과 연습기록 영역이 스크롤되도록 한다.
  void showReviewRecordPopup({
    required String targetItem,
    required List<FeedbackResult> results,
  }) {
    final sortedResults = sortResultsByDate(results);

    final ScrollController popupContentScrollController = ScrollController();
    final ScrollController recordListScrollController = ScrollController();

    void moveScrollController({
      required ScrollController controller,
      required DragUpdateDetails details,
    }) {
      if (!controller.hasClients) return;

      final double nextOffset = controller.offset - details.delta.dy;

      final double minOffset = controller.position.minScrollExtent;
      final double maxOffset = controller.position.maxScrollExtent;

      controller.jumpTo(
        nextOffset.clamp(minOffset, maxOffset),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        String selectedScoreType = '종합 점수';
        int selectedPointIndex = sortedResults.length - 1;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final reversedResults = sortedResults.reversed.toList();

            // 현재 카드 높이 70, 간격 12, 리스트 높이 260 기준으로
            // 약 3개까지는 한 화면에 자연스럽게 보이므로 스크롤을 막는다.
            final bool canScrollPopupContent = reversedResults.length > 1;
            final bool canScrollRecordList = reversedResults.length > 1;

            return Dialog(
              backgroundColor: Colors.white,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 620,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                  child: Column(
                    children: [
                      // 상단 제목과 X 버튼은 항상 고정
                      Row(
                        children: [
                          const SizedBox(width: 32),
                          Expanded(
                            child: Text(
                              '$targetItem 학습 추이',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
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
                              size: 32,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // 제목 아래 영역 전체 스크롤
                      // 기록이 많을 때만 스크롤 가능하다.
                      Expanded(
                        child: SingleChildScrollView(
                          controller: popupContentScrollController,
                          physics: canScrollPopupContent
                              ? const ClampingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  scoreTypeButton(
                                    text: '종합 점수',
                                    selectedScoreType: selectedScoreType,
                                    onTap: () {
                                      setDialogState(() {
                                        selectedScoreType = '종합 점수';
                                        selectedPointIndex =
                                            sortedResults.length - 1;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  scoreTypeButton(
                                    text: '음성 점수',
                                    selectedScoreType: selectedScoreType,
                                    onTap: () {
                                      setDialogState(() {
                                        selectedScoreType = '음성 점수';
                                        selectedPointIndex =
                                            sortedResults.length - 1;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  scoreTypeButton(
                                    text: '입모양 점수',
                                    selectedScoreType: selectedScoreType,
                                    onTap: () {
                                      setDialogState(() {
                                        selectedScoreType = '입모양 점수';
                                        selectedPointIndex =
                                            sortedResults.length - 1;
                                      });
                                    },
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // 그래프 영역
                              // 기록이 많을 때만 그래프 빈 영역 드래그로 전체 내용이 움직인다.
                              // 기록이 3개 이하이면 그래프 영역에서 드래그해도 반응하지 않는다.
                              GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onVerticalDragUpdate: canScrollPopupContent
                                    ? (details) {
                                  moveScrollController(
                                    controller:
                                    popupContentScrollController,
                                    details: details,
                                  );
                                }
                                    : null,
                                child: scoreTrendChart(
                                  sortedResults: sortedResults,
                                  scoreType: selectedScoreType,
                                  selectedPointIndex: selectedPointIndex,
                                  onPointTap: (index) {
                                    setDialogState(() {
                                      selectedPointIndex = index;
                                    });
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  '연습 기록',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // 연습 기록 영역
                              // 기록이 많을 때만 연습기록 카드 목록이 스크롤된다.
                              SizedBox(
                                height: 260,
                                child: ListView.separated(
                                  controller: recordListScrollController,
                                  physics: canScrollRecordList
                                      ? const ClampingScrollPhysics()
                                      : const NeverScrollableScrollPhysics(),
                                  itemCount: reversedResults.length,
                                  separatorBuilder: (context, index) {
                                    return const SizedBox(height: 12);
                                  },
                                  itemBuilder: (context, index) {
                                    final result = reversedResults[index];
                                    final originalIndex =
                                    sortedResults.indexOf(result);
                                    final practiceNumber = originalIndex + 1;

                                    final score = getScoreByType(
                                      result,
                                      selectedScoreType,
                                    );

                                    return reviewRecordCard(
                                      dialogContext: dialogContext,
                                      result: result,
                                      practiceNumber: practiceNumber,
                                      score: score,
                                    );
                                  },
                                ),
                              ),

                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      popupContentScrollController.dispose();
      recordListScrollController.dispose();
    });
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

  // 학습 주제 버튼 위젯
  // 저장된 피드백 기록이 있는 항목만 활성화한다.
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

  // 주제 버튼들을 가로 스크롤로 보여주는 위젯
  Widget itemRow(List<String> list) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: list.map((e) => buildCircleButton(e)).toList(),
      ),
    );
  }

  // 선택한 카테고리에 따라 주제 목록을 구성하는 함수
  // 자음, 모음, 단어, 문장별로 다른 주제 목록을 보여준다.
  Widget buildCategoryContent() {
    if (isLoadingEnabledItems) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

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
  // 학습, 복습 버튼을 만들 때 사용한다.
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

  // 화면 하단의 학습/복습 버튼 영역
  // 학습 버튼을 누르면 이전 학습모드 화면으로 돌아간다.
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
                const Duration(milliseconds: 150),
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

  // 복습모드의 메인 화면 영역
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