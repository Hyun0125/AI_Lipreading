# -*- coding: utf-8 -*-
"""Restore the pre-calendar FeedbackResult model and add the two score-presence flags.

Run this script from C:/Users/danee/StudioProjects/test_flutter/test_flutter.
Never switches branches, commits, pushes, or modifies other Dart files.
"""
from pathlib import Path
import subprocess
import hashlib
import sys

HERE = Path(__file__).resolve().parent
TARGET = HERE / 'lib' / 'models' / 'feedback_result.dart'
ROOT = HERE.parent.parent
COMMIT = 'c7f7cf9'
GIT_PATH = 'test_flutter/test_flutter/lib/models/feedback_result.dart'
EXPECTED_CALENDAR_PATCH_SHA256 = '6a64340c763aec034f8690a515563b6c9d1e0c5c5f33637d54044931f0d8b190'

def normalized(s):
    return s.replace('\r\n', '\n')

def add_once(s, old, new):
    if s.count(old) != 1:
        raise RuntimeError(f'예상한 코드 위치를 찾지 못했습니다: {old!r}; 원본 파일은 그대로 유지됩니다.')
    return s.replace(old, new, 1)

def main():
    if not TARGET.is_file():
        raise RuntimeError(f'현재 FeedbackResult 모델이 없습니다: {TARGET}')
    current = normalized(TARGET.read_text(encoding='utf-8-sig'))
    digest = hashlib.sha256(current.encode('utf-8')).hexdigest()
    if digest != EXPECTED_CALENDAR_PATCH_SHA256:
        raise RuntimeError('현재 모델이 배포한 캘린더 패치와 일치하지 않습니다. 다른 작업을 덮어쓰지 않도록 중단했습니다. 기존 파일은 그대로입니다.')

    command = ['git', '-C', str(ROOT), 'show', f'{COMMIT}:{GIT_PATH}']
    proc = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    if proc.returncode:
        raise RuntimeError('백업 커밋을 읽지 못했습니다. ' + proc.stderr.decode('utf-8', errors='replace'))
    restored = normalized(proc.stdout.decode('utf-8-sig'))
    if 'voiceAnalysis' not in restored:
        raise RuntimeError('Git 커밋의 모델에 voiceAnalysis가 없습니다. 파일을 안전하게 유지하고 중단했습니다.')
    if 'hasAudioTotalScore' in restored or 'hasVisualTotalScore' in restored:
        raise RuntimeError('기존 모델에 이미 점수 유무 필드가 있어 자동 병합을 중단했습니다.')

    restored = add_once(restored, '  final double audioTotalScore;',
                        '  final double audioTotalScore;\n  final bool hasAudioTotalScore;')
    restored = add_once(restored, '  final double visualTotalScore;',
                        '  final double visualTotalScore;\n  final bool hasVisualTotalScore;')
    restored = add_once(restored, '    required this.audioTotalScore,',
                        '    required this.audioTotalScore,\n    this.hasAudioTotalScore = true,')
    restored = add_once(restored, '    required this.visualTotalScore,',
                        '    required this.visualTotalScore,\n    this.hasVisualTotalScore = true,')
    marker = 'return FeedbackResult('
    if restored.count(marker) != 1:
        raise RuntimeError('JSON 파싱 생성자 위치가 달라서 자동 병합을 중단했습니다.')
    restored = restored.replace(marker, marker +
        "\n      hasAudioTotalScore: json['audio_total_score'] is num || json['audio_score'] is num," +
        "\n      hasVisualTotalScore: json['visual_total_score'] is num || json['visual_score'] is num,", 1)

    # Safety: never replace the source unless the merged version retains the voice field.
    if not all(part in restored for part in ['voiceAnalysis', 'hasAudioTotalScore', 'hasVisualTotalScore']):
        raise RuntimeError('결과 필드 검증이 실패하여 수정하지 않았습니다.')
    backup_folder = HERE / 'model_backups'
    backup_folder.mkdir(exist_ok=True)
    backup_path = backup_folder / 'feedback_result_before_compat_fix.dart.bak'
    if backup_path.exists():
        raise RuntimeError(f'백업 파일이 이미 존재합니다: {backup_path}; 덮어쓰기 방지를 위해 중단했습니다.')
    backup_path.write_text(current, encoding='utf-8')
    TARGET.write_text(restored, encoding='utf-8')
    print('복구 성공:', TARGET)
    print('이전 파일 백업:', backup_path)
    print('voiceAnalysis + hasAudioTotalScore + hasVisualTotalScore 유지')
    print('다음 실행: flutter analyze')

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print('자동 수정 중단:', exc, file=sys.stderr)
        sys.exit(1)
