from difflib import SequenceMatcher
import unicodedata


def normalize_text(text):
    """Ignore whitespace, punctuation, and letter case; retain letters/numbers."""
    text = unicodedata.normalize("NFC", text).casefold()
    return "".join(char for char in text if char.isalnum())


def compare_text(reference_text, recognized_text):
    """Compare transcription text, without judging pronunciation or meaning."""
    if reference_text is None:
        return None
    reference = normalize_text(reference_text)
    if not reference:
        raise ValueError("기준 문장에는 글자 또는 숫자가 포함되어야 합니다.")
    recognized = normalize_text(recognized_text)
    matcher = SequenceMatcher(None, reference, recognized, autojunk=False)
    differences = []
    for operation, start_ref, end_ref, start_rec, end_rec in matcher.get_opcodes():
        if operation != "equal":
            differences.append({
                "operation": operation,
                "expected": reference[start_ref:end_ref],
                "recognized": recognized[start_rec:end_rec],
                "reference_start": start_ref,
                "reference_end": end_ref,
                "recognized_start": start_rec,
                "recognized_end": end_rec,
            })
    return {
        "reference_text": reference_text,
        "recognized_text": recognized_text,
        "exact_match": reference_text == recognized_text,
        "normalized_match": reference == recognized,
        "character_similarity_percent": round(matcher.ratio() * 100, 2),
        "normalized_reference": reference,
        "normalized_recognized": recognized,
        "differences": differences,
    }
