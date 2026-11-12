"""Run one real recorded video through the chosen analysis branch and print per-stage times.
Usage (from backend root): python tools/benchmark_pipeline.py --video PATH --category 모음 --target ㅏ
"""
import argparse
import json
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from ai.analyze import analyze_pronunciation


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--video', type=Path, required=True)
    parser.add_argument('--category', choices=['자음','모음','문장'], required=True)
    parser.add_argument('--target', required=True)
    args = parser.parse_args()
    if not args.video.is_file():
        parser.error('영상 파일을 찾을 수 없습니다: '+str(args.video))
    start=time.perf_counter()
    result=analyze_pronunciation(str(args.video),args.category,args.target)
    elapsed=time.perf_counter()-start
    details=result.get('analysis_timing_ms',{})
    if args.category=='문장':
        details=result.get('voice_analysis',{}).get('analysis_timing_ms',details)
    print(json.dumps({'category':args.category,'target':args.target,
       'total_wall_seconds':round(elapsed,3),'stages_ms':details,
       'recognized_text':result.get('whisper_result'),
       'audio_total_score':result.get('audio_total_score'),
       'visual_total_score':result.get('visual_total_score')},ensure_ascii=False,indent=2))

if __name__=='__main__': main()
