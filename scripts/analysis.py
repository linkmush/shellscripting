#!/usr/bin/env python3
"""
analysis.py
Enkel logganalys för att demonstrera detektion av ovanligt antal misslyckade inloggningsförsök.
Input: katalog med loggfiler (text)
Output: JSON-rapport med summering och upptäckta anomalier
"""

import argparse
import json
import os
import re
from collections import defaultdict

AUTH_FAIL_PATTERNS = [
    re.compile(r'Failed password for', re.IGNORECASE),
    re.compile(r'authentication failure', re.IGNORECASE),
    re.compile(r'Invalid user', re.IGNORECASE),
]


def parse_args():
    p = argparse.ArgumentParser(description='Simple log analyzer')
    p.add_argument('--input-dir', required=True)
    p.add_argument('--output', required=True)
    p.add_argument('--threshold', type=int, default=5, help='Threshold for failed attempts to flag anomaly')
    return p.parse_args()


def analyze_syslog(path, counters):
    with open(path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            for pat in AUTH_FAIL_PATTERNS:
                if pat.search(line):
                    m = re.search(r'(\d{1,3}(?:\.\d{1,3}){3})', line)
                    ip = m.group(1) if m else 'unknown'
                    counters['failed_by_ip'][ip] += 1
                    counters['failed_total'] += 1


def main():
    args = parse_args()
    counters = {
        'failed_by_ip': defaultdict(int),
        'failed_total': 0,
    }

    for root, _, files in os.walk(args.input_dir):
        for fn in files:
            path = os.path.join(root, fn)
            if fn.endswith('.log') or 'auth' in fn.lower() or 'syslog' in fn.lower():
                try:
                    analyze_syslog(path, counters)
                except Exception as e:
                    print(f"Could not analyze {path}: {e}")

    anomalies = []
    for ip, count in counters['failed_by_ip'].items():
        if count >= args.threshold:
            anomalies.append({'ip': ip, 'count': count})

    report = {
        'summary': {
            'failed_total': counters['failed_total'],
            'unique_failed_ips': len(counters['failed_by_ip'])
        },
        'anomalies': anomalies
    }

    with open(args.output, 'w', encoding='utf-8') as out:
        json.dump(report, out, indent=2)

    print(f"Analysis complete. Report written to {args.output}")

if __name__ == '__main__':
    main()
