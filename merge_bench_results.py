#!/usr/bin/env python3
"""
Merge per-build llama-bench jsonl files into a single structured JSON report.
Called by run_bench_compare.sh after all builds have been benchmarked.
"""

import argparse
import json
import os
import platform
import socket
import subprocess
import sys
from datetime import datetime, timezone


def read_cpu_model() -> str:
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except OSError:
        pass
    return "unknown"


def read_rocm_version() -> str:
    version_file = "/opt/rocm/core-7.13/include/rocm-core/rocm_version.h"
    try:
        with open(version_file) as f:
            for line in f:
                if "ROCM_BUILD_INFO" in line:
                    parts = line.split('"')
                    if len(parts) >= 2:
                        return parts[1]
    except OSError:
        pass
    try:
        result = subprocess.run(
            ["rocminfo"], capture_output=True, text=True, timeout=5
        )
        for line in result.stdout.splitlines():
            if "ROCm Runtime Version" in line:
                return line.split(":", 1)[-1].strip()
    except Exception:
        pass
    return "7.13.0"


def read_gpu_info() -> list[dict]:
    gpus = []
    try:
        result = subprocess.run(
            ["rocm-smi", "--showproductname", "--csv"],
            capture_output=True, text=True, timeout=10,
        )
        for line in result.stdout.splitlines():
            if line.startswith("card") or line.startswith("GPU"):
                gpus.append({"rocm_smi": line.strip()})
    except Exception:
        pass
    if not gpus:
        gpus.append({"note": "rocm-smi not available or no AMD GPU detected"})
    return gpus


def load_jsonl(path: str) -> list[dict]:
    records = []
    if not os.path.isfile(path):
        return records
    with open(path) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                records.append(json.loads(line))
            except json.JSONDecodeError as exc:
                print(f"  WARNING: could not parse line {i} in {path}: {exc}", file=sys.stderr)
    return records


def summarise(records: list[dict]) -> dict:
    """Compute mean/min/max for key throughput fields across repetitions."""
    if not records:
        return {}

    def stats(values: list[float]) -> dict:
        if not values:
            return {}
        return {
            "mean": round(sum(values) / len(values), 4),
            "min":  round(min(values), 4),
            "max":  round(max(values), 4),
            "n":    len(values),
        }

    # llama-bench jsonl fields of interest
    pp_speeds = [r["avg_ts"] for r in records if r.get("n_prompt", 0) > 0]
    tg_speeds = [r["avg_ts"] for r in records if r.get("n_gen", 0) > 0]

    return {
        "prompt_processing_tok_per_s": stats(pp_speeds),
        "token_generation_tok_per_s":  stats(tg_speeds),
    }


def main():
    parser = argparse.ArgumentParser(description="Merge llama-bench jsonl results into JSON")
    parser.add_argument("--results-dir", required=True)
    parser.add_argument("--labels",      required=True, nargs="+")
    parser.add_argument("--model",       required=True)
    parser.add_argument("--output",      required=True)
    args = parser.parse_args()

    report = {
        "metadata": {
            "date":         datetime.now(timezone.utc).isoformat(),
            "host":         socket.gethostname(),
            "os":           platform.platform(),
            "cpu":          read_cpu_model(),
            "rocm_version": read_rocm_version(),
            "gpu":          read_gpu_info(),
            "model":        os.path.basename(args.model),
            "model_path":   args.model,
        },
        "builds": {},
        "results": {},
        "summary": {},
    }

    for label in args.labels:
        jsonl_path = os.path.join(args.results_dir, f"{label}.jsonl")
        log_path   = os.path.join(args.results_dir, f"{label}.jsonl.log")

        records = load_jsonl(jsonl_path)
        print(f"  {label}: loaded {len(records)} records from {jsonl_path}")

        report["builds"][label] = {
            "binary":   f"build-{label}/bin/llama-bench",
            "raw_jsonl": jsonl_path,
            "raw_log":   log_path,
        }
        report["results"][label]  = records
        report["summary"][label]  = summarise(records)

    with open(args.output, "w") as f:
        json.dump(report, f, indent=2)

    print(f"\nReport written: {args.output}")
    print("\nSummary:")
    for label, s in report["summary"].items():
        pp = s.get("prompt_processing_tok_per_s", {})
        tg = s.get("token_generation_tok_per_s", {})
        print(f"  [{label}]")
        if pp:
            print(f"    PP  mean={pp['mean']:.2f}  min={pp['min']:.2f}  max={pp['max']:.2f}  tok/s")
        if tg:
            print(f"    TG  mean={tg['mean']:.2f}  min={tg['min']:.2f}  max={tg['max']:.2f}  tok/s")


if __name__ == "__main__":
    main()
