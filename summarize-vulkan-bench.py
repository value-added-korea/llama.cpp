#!/usr/bin/env python3
"""
summarize-vulkan-bench.py

Parses llama-bench JSONL results and prints a side-by-side comparison table:
official Vulkan container vs. custom AOCC Vulkan build.

Each llama-bench row is one of three types:
  pp-only  : n_prompt > 0, n_gen == 0  → avg_ts = prompt processing speed (t/s)
  tg-only  : n_prompt == 0, n_gen > 0  → avg_ts = token generation speed (t/s)
  pg-combo : n_prompt > 0, n_gen > 0   → avg_ts = token generation speed (t/s)
             (pp speed for this context size comes from the matching pp-only row)

The table shows one row per (model, ngl, fa, n_prompt, n_gen) combination with
the correct speed column populated and the delta computed on that speed.

Usage:
    python3 summarize-vulkan-bench.py bench_raw/2026-06-03
    python3 summarize-vulkan-bench.py bench_raw/2026-06-03 --csv
    python3 summarize-vulkan-bench.py bench_raw/2026-06-03 --md

Verdict thresholds (on the measured t/s):
    >= +10%  : AOCC WINS (+)
    +5..+10% : aocc wins
    -5..+5%  : ≈ equal
    -5..-10% : ctr wins
    <= -10%  : CTR WINS (-)
"""

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path


ENGINE_CONTAINER = "container"
ENGINE_LOCAL     = "aocc-vulkan-release"

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


def row_type(r: dict) -> str:
    """Classify a llama-bench record."""
    n_prompt = r.get("n_prompt", 0)
    n_gen    = r.get("n_gen",    0)
    if n_prompt > 0 and n_gen == 0:
        return "pp"
    if n_prompt == 0 and n_gen > 0:
        return "tg"
    return "pg"   # combined -pg row; avg_ts = tg speed


def parse_results(results_dir: Path) -> dict:
    """
    Returns:
      {
        (model_tag, ngl, fa, n_prompt, n_gen, row_type): {
            ENGINE_CONTAINER: {"ts": float, "std": float, "engine_label": str, ...},
            ENGINE_LOCAL:     { same },
        }
      }

    Key uses row_type string so pp-only, tg-only, and pg-combo rows stay separate.
    """
    data = defaultdict(dict)

    for jsonl_file in sorted(results_dir.glob("*.jsonl")):
        name = jsonl_file.stem

        parts = name.split("_")
        if len(parts) < 2:
            continue

        engine_raw = parts[-1]
        model_tag  = "_".join(parts[:-1])

        # Only process Vulkan engine files
        if "vulkan" not in engine_raw and "container-vulkan" not in name:
            continue

        if "container" in engine_raw:
            engine = ENGINE_CONTAINER
            engine_label = engine_raw
        else:
            engine = ENGINE_LOCAL
            engine_label = engine_raw

        records = load_jsonl(jsonl_file)
        if not records:
            print(f"  [WARN] No records in {jsonl_file.name}", file=sys.stderr)
            continue

        for r in records:
            ngl      = r.get("n_gpu_layers", "?")
            fa       = r.get("flash_attn",   -1)
            n_prompt = r.get("n_prompt",      0)
            n_gen    = r.get("n_gen",         0)
            rtype    = row_type(r)
            ts       = r.get("avg_ts",    0.0)
            std      = r.get("stddev_ts", 0.0)

            key = (model_tag, ngl, fa, n_prompt, n_gen, rtype)
            data[key][engine] = {
                "ts":           ts,
                "std":          std,
                "build_commit": r.get("build_commit", "?"),
                "build_number": r.get("build_number", "?"),
                "backends":     r.get("backends",     "?"),
                "engine_label": engine_label,
            }

    return data


def delta_pct(local_ts: float, ctr_ts: float) -> float:
    if ctr_ts and ctr_ts > 0:
        return (local_ts - ctr_ts) / ctr_ts * 100.0
    return 0.0


def verdict(delta: float) -> str:
    if   delta >= 10:  return "AOCC WINS (+)"
    elif delta >=  5:  return "aocc wins"
    elif delta <= -10: return "CTR WINS (-)"
    elif delta <=  -5: return "ctr wins"
    else:              return "≈ equal"


# Column layout: (header, width)
COLS = [
    ("Model",        24),
    ("ngl",           5),
    ("FA",            3),
    ("test",         14),   # e.g. "pp512", "tg128", "pg512→128"
    ("metric",        5),   # "pp" or "tg"
    ("ctr  t/s",     10),
    ("aocc t/s",     10),
    ("Δ %",           8),
    ("Verdict",      14),
]


def format_test(n_prompt: int, n_gen: int, rtype: str) -> str:
    if rtype == "pp":
        return f"pp{n_prompt}"
    if rtype == "tg":
        return f"tg{n_gen}"
    return f"pg{n_prompt}→{n_gen}"


def print_table(data: dict, fmt: str = "text") -> None:
    if fmt == "md":
        sep = "|"
        print(sep + sep.join(f" {c[0]:<{c[1]}} " for c in COLS) + sep)
        print(sep + sep.join(" " + "-" * c[1] + " " for c in COLS) + sep)
    elif fmt == "csv":
        print(",".join(c[0] for c in COLS))
    else:
        header = "  ".join(f"{c[0]:<{c[1]}}" for c in COLS)
        print(header)
        print("-" * len(header))

    prev_model = None

    for key in sorted(data.keys()):
        model_tag, ngl, fa, n_prompt, n_gen, rtype = key
        engines = data[key]

        ctr  = engines.get(ENGINE_CONTAINER, {})
        aocc = engines.get(ENGINE_LOCAL,     {})

        if not ctr and not aocc:
            continue

        model_short = MODEL_SHORT.get(model_tag, model_tag)
        fa_label    = "on" if fa == 1 else "off" if fa == 0 else "?"
        test_label  = format_test(n_prompt, n_gen, rtype)
        metric      = "tg" if rtype in ("tg", "pg") else "pp"

        ctr_ts  = ctr.get("ts",  0.0) if ctr  else None
        aocc_ts = aocc.get("ts", 0.0) if aocc else None

        ctr_str  = f"{ctr_ts:>8.1f}"  if ctr_ts  is not None else "       -"
        aocc_str = f"{aocc_ts:>8.1f}" if aocc_ts is not None else "       -"

        if ctr_ts is not None and aocc_ts is not None:
            d    = delta_pct(aocc_ts, ctr_ts)
            vtxt = verdict(d)
            d_str = f"{d:+.1f}%"
        else:
            d_str = "-"
            vtxt  = "-"

        # Blank model name on repeated rows for readability
        if fmt == "text":
            display_model = model_short if model_short != prev_model else ""
        else:
            display_model = model_short
        prev_model = model_short

        row = [
            display_model,
            str(ngl),
            fa_label,
            test_label,
            metric,
            ctr_str.strip(),
            aocc_str.strip(),
            d_str,
            vtxt,
        ]

        if fmt == "md":
            print("|" + "|".join(f" {v:<{COLS[i][1]}} " for i, v in enumerate(row)) + "|")
        elif fmt == "csv":
            print(",".join(f'"{v}"' for v in row))
        else:
            print("  ".join(f"{v:<{COLS[i][1]}}" for i, v in enumerate(row)))

    if fmt == "text":
        print()
        print("metric: pp = prompt processing speed (t/s)  |  tg = token generation speed (t/s)")
        print("test:   pp<N> = pp-only  |  tg<N> = tg-only  |  pg<pp>→<tg> = combined -pg run")
        print()
        print("Δ % = (aocc − container) / container × 100   [positive = AOCC faster]")
        print()
        print("Verdict:  AOCC WINS (+) ≥+10%  |  aocc wins +5..+10%  |  ≈ equal ±5%")
        print("          ctr wins -5..-10%     |  CTR WINS (-)  ≤-10%")


def print_build_info(data: dict) -> None:
    seen: dict = {}
    for engines in data.values():
        for eng, entry in engines.items():
            label = entry.get("engine_label", eng)
            if label not in seen:
                seen[label] = entry
    print("Build info:")
    for label, e in seen.items():
        print(f"  {label:<35} build={e['build_number']}  commit={e['build_commit']}  backends={e['backends']}")
    print()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("results_dir", help="bench_raw/YYYY-MM-DD directory")
    parser.add_argument("--csv", action="store_true")
    parser.add_argument("--md",  action="store_true")
    args = parser.parse_args()

    results_dir = Path(args.results_dir)
    if not results_dir.is_dir():
        print(f"ERROR: not a directory: {results_dir}", file=sys.stderr)
        sys.exit(1)

    data = parse_results(results_dir)
    if not data:
        print(f"ERROR: no Vulkan JSONL records found in {results_dir}", file=sys.stderr)
        sys.exit(1)

    fmt = "csv" if args.csv else "md" if args.md else "text"

    if fmt == "text":
        print(f"\nllama.cpp Vulkan Benchmark — {results_dir.name}")
        print("GPU: AMD Radeon 780M iGPU (RADV PHOENIX / gfx1103, UMA)")
        print("=" * 80)
        print_build_info(data)

    print_table(data, fmt)


if __name__ == "__main__":
    main()
