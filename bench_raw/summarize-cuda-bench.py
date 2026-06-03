#!/usr/bin/env python3
"""
summarize-cuda-bench.py

Parses llama-bench JSONL results from a dated bench_raw directory and prints
a side-by-side comparison table: container vs. custom AOCC CUDA build.

Usage:
    python3 summarize-cuda-bench.py bench_raw/2026-06-03
    python3 summarize-cuda-bench.py bench_raw/2026-06-03 --csv > results.csv
    python3 summarize-cuda-bench.py bench_raw/2026-06-03 --md   > results.md

Output fields per row:
    model | ngl | flash_attn | n_prompt | n_gen | engine | pp t/s | tg t/s
    + delta columns comparing the two engines

Verdict thresholds (tg_avg_ts):
    >= +10%  : custom build clearly wins
    +5..+10% : custom build wins
    -5..+5%  : too close to call — container is good enough
    < -5%    : container wins
"""

import argparse
import json
import os
import sys
from collections import defaultdict
from pathlib import Path


ENGINE_CONTAINER = "container"
ENGINE_LOCAL = "aocc-cuda13-reldbg"

MODEL_SHORT = {
    "qwen25-coder-7b-q4km": "Qwen2.5-7B Q4_K_M",
    "omnicoder-9b-q4km":    "OmniCoder-9B Q4_K_M",
    "qwen3-27b-q3kxl":      "Qwen3.6-27B Q3_K_XL",
}


def load_jsonl(path: Path) -> list[dict]:
    records = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line.startswith("{"):
                try:
                    records.append(json.loads(line))
                except json.JSONDecodeError:
                    pass
    return records


def parse_results(results_dir: Path) -> dict:
    """
    Returns: {
        (model_tag, ngl, flash_attn, n_prompt, n_gen): {
            "container": {"pp": float, "pp_std": float, "tg": float, "tg_std": float, "build": str},
            "local":     { same },
        }
    }
    """
    data = defaultdict(dict)

    for jsonl_file in sorted(results_dir.glob("*.jsonl")):
        name = jsonl_file.stem  # e.g. qwen25-coder-7b-q4km_container-b9449

        # Split on last underscore that precedes the engine tag
        parts = name.split("_")
        if len(parts) < 2:
            continue

        engine_raw = parts[-1]  # container-b9449  or  aocc-cuda13-reldbg
        model_tag = "_".join(parts[:-1])  # qwen25-coder-7b-q4km

        if "container" in engine_raw:
            engine = ENGINE_CONTAINER
            engine_label = engine_raw          # container-b9449
        else:
            engine = ENGINE_LOCAL
            engine_label = engine_raw          # aocc-cuda13-reldbg

        records = load_jsonl(jsonl_file)
        if not records:
            print(f"  [WARN] No records in {jsonl_file.name}", file=sys.stderr)
            continue

        for r in records:
            ngl      = r.get("n_gpu_layers", "?")
            fa       = r.get("flash_attn", -1)
            n_prompt = r.get("n_prompt", 0)
            n_gen    = r.get("n_gen", 0)
            pp       = r.get("avg_ts") if n_gen == 0 else None
            tg       = r.get("avg_ts") if n_prompt == 0 else None

            # llama-bench emits separate rows for pp (n_gen=0) and tg (n_prompt=0)
            # and combined rows for -pg pairs (n_prompt>0, n_gen>0) where avg_ts = tg speed
            # For -pg mode: avg_ts is token generation speed; pp speed appears in a companion row.
            # We treat any row with n_prompt>0 and n_gen>0 as a combined entry.
            pp_avg   = r.get("avg_ts", 0.0)
            pp_std   = r.get("stddev_ts", 0.0)
            tg_avg   = r.get("avg_ts", 0.0)
            tg_std   = r.get("stddev_ts", 0.0)

            key = (model_tag, ngl, fa, n_prompt, n_gen)

            entry = {
                "pp": pp_avg,
                "pp_std": pp_std,
                "tg": tg_avg,
                "tg_std": tg_std,
                "build_commit": r.get("build_commit", "?"),
                "build_number": r.get("build_number", "?"),
                "backends": r.get("backends", "?"),
                "engine_label": engine_label,
            }
            data[key][engine] = entry

    return data


def delta_pct(val_local, val_container) -> float:
    if val_container and val_container > 0:
        return (val_local - val_container) / val_container * 100.0
    return 0.0


def verdict(delta: float) -> str:
    if delta >= 10:
        return "AOCC WINS (+)"
    elif delta >= 5:
        return "aocc wins"
    elif delta <= -10:
        return "CTR WINS (-)"
    elif delta <= -5:
        return "ctr wins"
    else:
        return "≈ equal"


def print_table(data: dict, fmt: str = "text") -> None:
    COLS = [
        ("Model",          24),
        ("ngl",             5),
        ("FA",              3),
        ("pp",              6),
        ("tg",              6),
        ("ctr pp t/s",     11),
        ("ctr tg t/s",     11),
        ("aocc pp t/s",    11),
        ("aocc tg t/s",    11),
        ("Δtg %",           8),
        ("Verdict",        14),
    ]

    if fmt == "md":
        sep = "|"
        header_parts = [f" {c[0]:<{c[1]}} " for c in COLS]
        print(sep + sep.join(header_parts) + sep)
        print(sep + sep.join([" " + "-" * c[1] + " " for c in COLS]) + sep)
    elif fmt == "csv":
        print(",".join(c[0] for c in COLS))
    else:
        widths = [c[1] for c in COLS]
        header = "  ".join(f"{c[0]:<{c[1]}}" for c in COLS)
        print(header)
        print("-" * len(header))

    models_seen = set()

    for key in sorted(data.keys()):
        model_tag, ngl, fa, n_prompt, n_gen = key
        engines = data[key]

        ctr  = engines.get(ENGINE_CONTAINER, {})
        aocc = engines.get(ENGINE_LOCAL, {})

        if not ctr and not aocc:
            continue

        model_short = MODEL_SHORT.get(model_tag, model_tag)
        fa_label = "on" if fa == 1 else "off" if fa == 0 else "?"
        pp_label = f"{n_prompt}" if n_prompt else "-"
        tg_label = f"{n_gen}"    if n_gen    else "-"

        ctr_pp  = f"{ctr.get('pp', 0.0):>8.1f}"  if ctr  else "       -"
        ctr_tg  = f"{ctr.get('tg', 0.0):>8.1f}"  if ctr  else "       -"
        aocc_pp = f"{aocc.get('pp', 0.0):>8.1f}" if aocc else "       -"
        aocc_tg = f"{aocc.get('tg', 0.0):>8.1f}" if aocc else "       -"

        d_tg  = delta_pct(aocc.get("tg", 0), ctr.get("tg", 0)) if (ctr and aocc) else 0.0
        vtxt  = verdict(d_tg) if (ctr and aocc) else "-"

        row = [
            model_short,
            str(ngl),
            fa_label,
            pp_label,
            tg_label,
            ctr_pp.strip(),
            ctr_tg.strip(),
            aocc_pp.strip(),
            aocc_tg.strip(),
            f"{d_tg:+.1f}%",
            vtxt,
        ]

        if fmt == "md":
            cells = [f" {v:<{COLS[i][1]}} " for i, v in enumerate(row)]
            print("|" + "|".join(cells) + "|")
        elif fmt == "csv":
            print(",".join(f'"{v}"' for v in row))
        else:
            line = "  ".join(f"{v:<{COLS[i][1]}}" for i, v in enumerate(row))
            print(line)

        models_seen.add(model_tag)

    if fmt == "text":
        print()
        print("Δtg % = (aocc_tg - container_tg) / container_tg × 100")
        print("Positive = AOCC custom build is faster at token generation")
        print()
        print("Verdict scale:")
        print("  AOCC WINS (+) : >= +10% advantage for custom build")
        print("  aocc wins     :  +5..+10%")
        print("  ≈ equal       :  -5..+5%  → container is good enough")
        print("  ctr wins      :  -5..-10%")
        print("  CTR WINS (-)  : <= -10%  → container wins")


def print_build_info(data: dict) -> None:
    """Print build commit/number for each engine seen."""
    seen = {}
    for engines in data.values():
        for eng, entry in engines.items():
            label = entry.get("engine_label", eng)
            commit = entry.get("build_commit", "?")
            number = entry.get("build_number", "?")
            backend = entry.get("backends", "?")
            key = (label, commit, number, backend)
            if label not in seen:
                seen[label] = key

    print("Build info:")
    for label, (lbl, commit, number, backend) in seen.items():
        print(f"  {lbl:<30} build_number={number}  commit={commit}  backends={backend}")
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results_dir", help="bench_raw/YYYY-MM-DD directory")
    parser.add_argument("--csv", action="store_true", help="Output CSV")
    parser.add_argument("--md",  action="store_true", help="Output Markdown table")
    args = parser.parse_args()

    results_dir = Path(args.results_dir)
    if not results_dir.is_dir():
        print(f"ERROR: not a directory: {results_dir}", file=sys.stderr)
        sys.exit(1)

    data = parse_results(results_dir)
    if not data:
        print(f"ERROR: no JSONL records found in {results_dir}", file=sys.stderr)
        sys.exit(1)

    fmt = "csv" if args.csv else "md" if args.md else "text"

    if fmt == "text":
        print(f"\nllama.cpp CUDA Benchmark Summary — {results_dir.name}")
        print("=" * 80)
        print_build_info(data)

    print_table(data, fmt)


if __name__ == "__main__":
    main()
