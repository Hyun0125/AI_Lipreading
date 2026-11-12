"""ETRI + Whisper 텍스트 기반 *재연습 후보* 탐지 (음향적 발음 오류 판정 아님).

외부 패키지 없음. 문장 점수(score)는 음소별 평가로 절대 변환하지 않는다.
"""
from __future__ import annotations

from collections import defaultdict
import re
import unicodedata

# 기존 phoneme_comparison.py와 동일한 완성형 한글 분해 순서
INITIALS = tuple("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
VOWELS = tuple("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ")
FINALS = (None, *tuple("ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ"))
_LABELS = ("initial", "vowel", "final")
_TOKEN_RE = re.compile(r"[^\W_]+", re.UNICODE)
_LIMITATION = (
    "Whisper/ETRI가 인식한 글자의 차이로 찾은 재연습 후보입니다. "
    "실제 발음 오류·음소별 정확도는 판정하지 않으며, 음운 변동·표기 차이와 음성 인식 오류가 포함될 수 있습니다."
)


def _parts(char: str):
    if len(char) != 1 or not "가" <= char <= "힣":
        return None
    n = ord(char) - ord("가")
    return INITIALS[n // 588], VOWELS[(n % 588) // 28], FINALS[n % 28]


def _sub_cost(a: str, b: str) -> float:
    if a == b:
        return 0.0
    left, right = _parts(a), _parts(b)
    if left and right:
        # 같은 음절 내 초·중·종성 차이를 작게 보아 불필요한 위치 밀림을 줄임.
        return sum(x != y for x, y in zip(left, right)) / 3
    return 1.0


def _prepare(text: str):
    normalized = unicodedata.normalize("NFC", text or "").casefold()
    tokens = [m.group() for m in _TOKEN_RE.finditer(normalized)]
    flat = "".join(tokens)
    char_word = [idx for idx, token in enumerate(tokens) for _ in token]
    char_local = [idx for token in tokens for idx in range(len(token))]
    return tokens, flat, char_word, char_local


def _align(left: str, right: str):
    """동적 계획법 기반 문자 정렬. (기준 인덱스, 인식 인덱스) 목록."""
    n, m = len(left), len(right)
    cost = [[0.0] * (m + 1) for _ in range(n + 1)]
    step = [[None] * (m + 1) for _ in range(n + 1)]
    for i in range(1, n + 1):
        cost[i][0], step[i][0] = float(i), "del"
    for j in range(1, m + 1):
        cost[0][j], step[0][j] = float(j), "ins"
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            possibilities = (
                (cost[i - 1][j - 1] + _sub_cost(left[i - 1], right[j - 1]), "pair"),
                (cost[i - 1][j] + 1, "del"),
                (cost[i][j - 1] + 1, "ins"),
            )
            cost[i][j], step[i][j] = min(possibilities, key=lambda pair: pair[0])
    alignment = []
    i, j = n, m
    while i or j:
        operation = step[i][j]
        alignment.append((i - 1 if operation != "ins" else None,
                          j - 1 if operation != "del" else None))
        i -= operation != "ins"
        j -= operation != "del"
    alignment.reverse()
    return alignment


def _component_changes(expected: str | None, recognized: str | None):
    a = _parts(expected) if expected else None
    b = _parts(recognized) if recognized else None
    if not a or not b:
        return []
    return [
        {"position": name, "expected": av, "recognized": bv}
        for name, av, bv in zip(_LABELS, a, b) if av != bv
    ]


def _compare_one(reference: str, transcript: str):
    """기준 단어 인덱스별 차이. 비어 있는 인식은 전체 누락으로 간주하지 않음."""
    ref_words, a, ref_word_map, ref_local = _prepare(reference)
    _, b, _, _ = _prepare(transcript)
    if not b or not a:
        return {}
    if len(a) > 500 or len(b) > 500:
        return {}  # 비정상적으로 긴 입력에서 O(n*m) 계산 방지
    pairs = _align(a, b)
    positions: dict[int, dict] = defaultdict(lambda: {"recognition_indices": set(), "differences": []})
    for k, (i, j) in enumerate(pairs):
        if i is not None:
            word_index = ref_word_map[i]
        else:
            # 삽입 문자는 인접한 기준 단어에 귀속 (단어 경계는 애매할 수 있음)
            prev = next((pairs[z][0] for z in range(k - 1, -1, -1) if pairs[z][0] is not None), None)
            next_idx = next((pairs[z][0] for z in range(k + 1, len(pairs)) if pairs[z][0] is not None), None)
            neighbor = prev if prev is not None else next_idx
            if neighbor is None:
                continue
            word_index = ref_word_map[neighbor]
        record = positions[word_index]
        if j is not None:
            record["recognition_indices"].add(j)
        expected = a[i] if i is not None else None
        recognized = b[j] if j is not None else None
        if expected == recognized:
            continue
        record["differences"].append({
            "reference_syllable_index": ref_local[i] if i is not None else None,
            "expected": expected,
            "recognized": recognized,
            "operation": "insert" if expected is None else "delete" if recognized is None else "replace",
            "jamo_changes": _component_changes(expected, recognized),
        })
    return {
        index: {
            "expected_word": ref_words[index],
            "recognized_word": "".join(b[j] for j in sorted(record["recognition_indices"])),
            "differences": record["differences"],
        }
        for index, record in positions.items() if record["differences"]
    }


def detect_correction_candidates(
    reference_text: str,
    whisper_text: str | None = None,
    etri_text: str | None = None,
    etri_score: float | None = None,
    *,
    max_candidates: int = 5,
) -> dict:
    """실제 API 호출 없이 문장 비교 결과를 JSON 호환 딕셔너리로 반환."""
    if not isinstance(reference_text, str) or not _prepare(reference_text)[1]:
        raise ValueError("교정 후보 탐지에는 비어 있지 않은 기준 문장이 필요합니다.")
    if max_candidates < 1:
        raise ValueError("max_candidates는 1 이상이어야 합니다.")
    words, flat, _, _ = _prepare(reference_text)
    sources = {
        "whisper": (whisper_text or "").strip(),
        "etri": (etri_text or "").strip(),
    }
    available = [source for source, val in sources.items() if _prepare(val)[1]]
    result = {
        "method": "transcript_alignment",
        "comparison_unit": "written_word_and_syllable",
        "reference_text": reference_text,
        "whisper_recognized_text": sources["whisper"],
        "etri_recognized_text": sources["etri"],
        "etri_sentence_score": etri_score,
        "available_sources": available,
        "status": "no_recognition",
        "candidates": [],
        "total_candidate_words": 0,
        "limitation": _LIMITATION,
        "summary": "음성 인식 결과가 없어 교정 후보를 만들 수 없습니다.",
    }
    if len(flat) > 500 or any(len(_prepare(val)[1]) > 500 for val in sources.values()):
        result.update(status="text_too_long", summary="문장이 너무 길어 교정 후보를 생성하지 않았습니다.")
        return result
    if not available:
        return result
    per_source = {source: _compare_one(reference_text, sources[source]) for source in available}
    candidate_indices = sorted(set().union(*(set(changes) for changes in per_source.values())))
    candidates = []
    for index in candidate_indices:
        evidence = [source for source in available if index in per_source[source]]
        if len(evidence) == 2:
            readings = [per_source[source][index]["recognized_word"] for source in evidence]
            priority = "high" if readings[0] == readings[1] else "medium"
        else:
            priority = "low"
        word = words[index]
        found = {
            "word_index": index,  # 0부터 시작하는 기준 문장 단어 인덱스
            "expected_word": word,
            "recognized_by_whisper": (
                per_source["whisper"][index]["recognized_word"]
                if "whisper" in evidence else sources["whisper"] and word or None
            ),
            "recognized_by_etri": (
                per_source["etri"][index]["recognized_word"]
                if "etri" in evidence else sources["etri"] and word or None
            ),
            "evidence_sources": evidence,
            "priority": priority,  # 재확인 순서. 발음 오류 신뢰도/확률이 아님
            "syllable_candidates": [
                {"source": source, **difference}
                for source in evidence for difference in per_source[source][index]["differences"]
            ],
            "feedback": (
                f"'{word}' 부분이 두 음성 인식 결과에서 다르게 인식되었어요. 다시 천천히 연습해 보세요."
                if len(evidence) == 2 else
                f"'{word}' 부분에서 인식 결과 차이가 있어요. 인식 오류일 수도 있으니 다시 확인해 보세요."
            ),
        }
        candidates.append(found)
    rank = {"high": 0, "medium": 1, "low": 2}
    candidates.sort(key=lambda entry: (rank[entry["priority"]], entry["word_index"]))
    result["total_candidate_words"] = len(candidates)
    result["candidates"] = candidates[:max_candidates]
    if candidates:
        result["status"] = "review_candidates"
        labels = []
        for x in result["candidates"]:
            # 동일 음절의 복수 인식 결과가 있어도 예시는 첫 번째 차이 하나만 보여준다.
            diffs = x["syllable_candidates"]
            example = next((d for d in diffs if d["expected"] and d["recognized"]), None)
            if example and example["expected"] != example["recognized"]:
                labels.append(f"{x['expected_word']}({example['expected']}→{example['recognized']})")
            else:
                labels.append(x["expected_word"])
        result["summary"] = (
            f"재확인할 단어·음절: {', '.join(labels)}. "
            "음성 인식 텍스트상의 차이이며 실제 발음 오류로 확정된 것은 아닙니다."
        )
    else:
        result["status"] = "no_text_difference"
        result["summary"] = "인식된 문장에서는 재확인할 글자 차이가 없어요. 발음 정확도까지 보장하는 것은 아닙니다."
    return result
