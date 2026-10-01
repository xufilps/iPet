#!/usr/bin/env python3
"""Wall-clock app/rendering soak. Defaults to the required two hours, not accelerated time."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--seconds', type=int, default=7200)
parser.add_argument('--output', type=Path, default=Path(__file__).resolve().parents[1] / 'build/soak-report.json')
args = parser.parse_args()
if args.seconds <= 0:
    parser.error('--seconds must be positive')
root = Path(__file__).resolve().parents[1]
binary = root / 'build/Build/Products/Release/VPetApple.app/Contents/MacOS/VPetApple'
args.output.parent.mkdir(parents=True, exist_ok=True)
log = args.output.with_suffix('.log')
samples = []
started = time.monotonic()
with log.open('w') as stream:
    child = subprocess.Popen([str(binary)], env=dict(os.environ, VPET_SMOKE_TEST='1', VPET_SOAK_SECONDS=str(args.seconds)), stdout=stream, stderr=stream)
    try:
        while child.poll() is None:
            output = subprocess.run(['ps', '-p', str(child.pid), '-o', '%cpu=,rss='], capture_output=True, text=True).stdout.split()
            if len(output) == 2:
                samples.append({'seconds': round(time.monotonic() - started, 2), 'cpuPercent': float(output[0]), 'rssKiB': int(output[1])})
            if time.monotonic() - started > args.seconds + 60:
                raise TimeoutError('App did not finish the soak')
            time.sleep(5)
    finally:
        if child.poll() is None:
            child.terminate()
            child.wait(timeout=15)
text = log.read_text()
report = {'requestedSeconds': args.seconds, 'elapsedSeconds': round(time.monotonic() - started, 2), 'exitCode': child.returncode, 'completed': child.returncode == 0 and 'VPET_SOAK_DONE' in text, 'samples': samples}
args.output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k != 'samples'}))
raise SystemExit(0 if report['completed'] else 1)
