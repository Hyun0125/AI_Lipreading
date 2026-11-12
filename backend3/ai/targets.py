import json
import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__)) 
GENERATED_TARGETS_PATH = os.path.join(BASE_DIR, "generated_targets.json")


DEFAULT_TARGETS = {
    "아": {
        "visual": {
            "target_avg": 1.00,
            "target_max": 1.10,
            "target_movement": 0.15
        },
        "audio_aliases": ["아"]
    },
    "어": {
        "visual": {
            "target_avg": 0.85,
            "target_max": 0.95,
            "target_movement": 0.13
        },
        "audio_aliases": ["어"]
    },
    "오": {
        "visual": {
            "target_avg": 0.55,
            "target_max": 0.65,
            "target_movement": 0.10
        },
        "audio_aliases": ["오"]
    },
    "우": {
        "visual": {
            "target_avg": 0.50,
            "target_max": 0.60,
            "target_movement": 0.10
        },
        "audio_aliases": ["우"]
    },
    "으": {
        "visual": {
            "target_avg": 0.25,
            "target_max": 0.35,
            "target_movement": 0.05
        },
        "audio_aliases": ["으"]
    },
    "이": {
        "visual": {
            "target_avg": 0.35,
            "target_max": 0.45,
            "target_movement": 0.06
        },
        "audio_aliases": ["이"]
    }
}


def load_targets():
    if os.path.exists(GENERATED_TARGETS_PATH):
        with open(GENERATED_TARGETS_PATH, "r", encoding="utf-8") as f:
            return json.load(f)

    return DEFAULT_TARGETS


TARGETS = load_targets()