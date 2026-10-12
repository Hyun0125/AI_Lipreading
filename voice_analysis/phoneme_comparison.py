"""Compare written Hangul components, not acoustic pronunciation quality."""

from collections import Counter, defaultdict

from .text_comparison import normalize_text

INITIALS = tuple("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
VOWELS = tuple("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
FINALS = (None, *tuple("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ"))
POSITIONS = ("initial", "vowel", "final")


def decompose_syllable(char):
    """Return (initial, vowel, final) for one precomposed Hangul syllable."""
    if len(char) != 1 or not "가" <= char <= "힣":
        return None
    code = ord(char) - ord("가")
    return INITIALS[code // 588], VOWELS[(code % 588) // 28], FINALS[code % 28]


def _substitution_cost(left, right):
    if left == right:
        return 0
    a, b = decompose_syllable(left), decompose_syllable(right)
    return sum(x != y for x, y in zip(a, b)) / 3 if a and b else 1


def _align(reference, recognized):
    # Global alignment prevents a missing syllable from shifting the entire suffix.
    rows, columns = len(reference), len(recognized)
    costs = [[0.0] * (columns + 1) for _ in range(rows + 1)]
    steps = {}
    for i in range(1, rows + 1):
        costs[i][0], steps[i, 0] = i, "delete"
    for j in range(1, columns + 1):
        costs[0][j], steps[0, j] = j, "insert"
    for i in range(1, rows + 1):
        for j in range(1, columns + 1):
            costs[i][j], steps[i, j] = min(
                (costs[i - 1][j - 1] + _substitution_cost(reference[i - 1], recognized[j - 1]), "pair"),
                (costs[i - 1][j] + 1, "delete"),
                (costs[i][j - 1] + 1, "insert"),
                key=lambda item: item[0],
            )
    alignment = []
    i, j = rows, columns
    while i or j:
        step = steps[i, j]
        alignment.append((i - 1 if step != "insert" else None,
                          j - 1 if step != "delete" else None))
        i -= step != "insert"
        j -= step != "delete"
    return list(reversed(alignment))


def compare_phonemes(reference_text, recognized_text):
    """Report written initial/vowel/final differences with normalized text indices."""
    if reference_text is None:
        return None
    reference, recognized = normalize_text(reference_text), normalize_text(recognized_text)
    if not reference:
        raise ValueError("기준 문장에는 글자 또는 숫자가 포함되어야 합니다.")
    totals = {position: Counter() for position in POSITIONS}
    symbols = defaultdict(Counter)
    confusions = defaultdict(Counter)
    differences = []
    for i, j in _align(reference, recognized):
        expected_char = reference[i] if i is not None else None
        actual_char = recognized[j] if j is not None else None
        expected = decompose_syllable(expected_char) if expected_char else None
        actual = decompose_syllable(actual_char) if actual_char else None
        for index, position in enumerate(POSITIONS):
            a = expected[index] if expected else None
            b = actual[index] if actual else None
            if a is None and b is None:
                continue
            operation = "match" if a == b else "insert" if a is None else "delete" if b is None else "replace"
            totals[position][operation] += 1
            if a is not None:
                symbols[position, a]["expected_count"] += 1
                symbols[position, a]["matched_count" if operation == "match" else "mismatch_count"] += 1
            if operation != "match":
                if a is not None:
                    confusions[position, a][b] += 1
                differences.append({
                    "position": position, "operation": operation,
                    "expected": a, "recognized": b,
                    "expected_syllable": expected_char, "recognized_syllable": actual_char,
                    "reference_index": i, "recognized_index": j,
                })
    def summarize(counts):
        result = {key + "_count": counts[key] for key in ("match", "replace", "delete", "insert")}
        count = sum(counts.values())
        result["similarity_percent"] = round(100 * counts["match"] / count, 2) if count else None
        return result

    combined = Counter()
    for counts in totals.values():
        combined.update(counts)
    assessment = []
    for (position, symbol), counts in sorted(symbols.items()):
        assessment.append({
            "position": position, "symbol": symbol,
            "expected_count": counts["expected_count"], "matched_count": counts["matched_count"],
            "mismatch_count": counts["mismatch_count"],
            "match_percent": round(100 * counts["matched_count"] / counts["expected_count"], 2),
            "confusions": [{"recognized": other, "count": count}
                           for other, count in confusions[position, symbol].items()],
        })
    return {
        "reference_text": reference_text, "recognized_text": recognized_text,
        "normalized_reference": reference, "normalized_recognized": recognized,
        "comparison_type": "written_hangul_components",
        "limitation": "음성 인식 텍스트의 차이이며 실제 발음 결함을 판정하지 않습니다. 연음·음운 변동은 반영하지 않습니다.",
        "overall": summarize(combined),
        "by_position": {position: summarize(counts) for position, counts in totals.items()},
        "symbols": assessment,
        "mismatched_symbols": [item for item in assessment if item["mismatch_count"]],
        "differences": differences,
    }
