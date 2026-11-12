import '../models/feedback_result.dart';

/// Converts both ISO timestamps and SQLite-style timestamps to local time.
/// An invalid/missing timestamp is not treated as a record from today.
DateTime? feedbackRecordedAt(FeedbackResult result) {
  final raw = result.createdAt.trim();
  if (raw.isEmpty) return null;
  final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
  return parsed?.toLocal();
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _isPhonemeResult(FeedbackResult result, String phoneme) =>
    result.targetItem == phoneme &&
    (result.category == '모음' || result.category == '자음');

int _newestFirst(FeedbackResult a, FeedbackResult b) {
  final first = feedbackRecordedAt(a);
  final second = feedbackRecordedAt(b);
  if (first == null && second == null) return 0;
  if (first == null) return 1;
  if (second == null) return -1;
  final timeOrder = second.compareTo(first);
  if (timeOrder != 0) return timeOrder;
  return (b.id ?? 0).compareTo(a.id ?? 0);
}

/// All saved analyses for the selected consonant/vowel, newest first.
/// Sentence assessments and local 'practice completed' flags are excluded.
List<FeedbackResult> savedPhonemeHistory(
    Iterable<FeedbackResult> records, String phoneme) {
  final selected = records.where((result) =>
      _isPhonemeResult(result, phoneme) &&
      feedbackRecordedAt(result) != null).toList();
  selected.sort(_newestFirst);
  return selected;
}

/// Saved analyses for exactly one local calendar day and one phoneme.
/// Returns every attempt, not just the newest one.
List<FeedbackResult> savedPhonemeDayHistory(
    Iterable<FeedbackResult> records, String phoneme, DateTime day) =>
  savedPhonemeHistory(records, phoneme).where((result) =>
    _sameDay(feedbackRecordedAt(result)!, day)).toList();

String feedbackDateLabel(DateTime time) =>
    '${time.year}.${time.month.toString().padLeft(2, '0')}.'
    '${time.day.toString().padLeft(2, '0')}';

String feedbackTimeLabel(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String feedbackScoreLabel(double value) => '${value.toStringAsFixed(0)}점';
