---
title: Tesslate/OmniCoder-9B · Hugging Face
published: "2026-03-12T06:59:33"
description: We’re on a journey to advance and democratize artificial intelligence through open source and open science.
source: "https://huggingface.co/Tesslate/OmniCoder-9B"
site: huggingface.co
saved: "2026-06-03T03:48:58.491Z"
---
![OmniCoder](/Tesslate/OmniCoder-9B/resolve/main/omnicoder-banner.png)

## OmniCoder-9B

### A 9B coding agent fine-tuned on 425K agentic trajectories.

!! 3/12/26 Update -> [Install For Your Coding Agents](https://tesslate.com/install#omnicoder)

[Get Started](#quickstart) | [Benchmarks](#benchmarks) | [GGUF Downloads](https://huggingface.co/Tesslate/OmniCoder-9B-GGUF)

---

## Overview

**OmniCoder-9B** is a 9-billion parameter coding agent model built by [Tesslate](https://tesslate.com), fine-tuned on top of [Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B) 's hybrid architecture (Gated Delta Networks interleaved with standard attention). It was trained on **425,000+ curated agentic coding trajectories** spanning real-world software engineering tasks, tool use, terminal operations, and multi-step reasoning.

The training data was specifically built from **Claude Opus 4.6 agentic and coding reasoning traces**, targeting scaffolding patterns from Claude Code, OpenCode, Codex, and Droid. The dataset includes successful trajectories from models like Claude Opus 4.6, GPT-5.4, GPT-5.3-Codex, and Gemini 3.1 Pro.

The model shows strong agentic behavior: it recovers from errors (read-before-write), responds to LSP diagnostics, and uses proper edit diffs instead of full rewrites. These patterns were learned directly from the real-world agent trajectories it was trained on.

### Key Features

-   **Trained on Frontier Agent Traces**: Built from Claude Opus 4.6, GPT-5.3-Codex, GPT-5.4, and Gemini 3.1 Pro agentic coding trajectories across Claude Code, OpenCode, Codex, and Droid scaffolding
-   **Hybrid Architecture**: Inherits Qwen3.5's Gated Delta Networks interleaved with standard attention for efficient long-context processing
-   **262K Native Context**: Full 262,144 token context window, extensible to 1M+
-   **Error Recovery**: Learns read-before-write patterns, responds to LSP diagnostics, and applies minimal edit diffs instead of full rewrites
-   **Thinking Mode**: Supports `<think>...</think>` reasoning chains for complex problem decomposition
-   **Apache 2.0**: Fully open weights, no restrictions

---

## Benchmarks

| Benchmark | **OmniCoder-9B** | Qwen3.5-9B | Qwen3-Next-80B | GPT-OSS-120B | GPT-OSS-20B | GLM-4.7-Flash | GLM 4.7 | Claude Haiku 4.5 |
| :-- | :-: | :-: | :-: | :-: | :-: | :-: | :-: | :-: |
| **AIME 2025** (pass@5) | 90 |  |  |  | 91.7 | 91.6 |  |  |
| **GPQA Diamond** (pass@1) | **83.8** | 81.7 | 77.2 | 80.1 | 71.5 |  |  | 73 |
| **GPQA Diamond** (pass@3) | **86.4** |  |  |  |  |  |  |  |
| **Terminal-Bench 2.0** | **23.6** | 14.6 |  |  |  |  | 33.4 | 27 |

-   **GPQA Diamond pass@1: 83.8%** (166/198). +2.1 points over the Qwen3.5-9B base model (81.7). At pass@3: **86.4** (171/198).
-   **AIME 2025 pass@5: 90%** (27/30).
-   **Terminal-Bench 2.0: 23.6%** (21/89). +8.99 points (+61% improvement) over the Qwen3.5-9B base model (14.6%, 13/89).

---

## Quickstart

### Transformers

```python
from transformers import AutoModelForCausalLM, AutoTokenizer

model_id = "Tesslate/OmniCoder-9B"

tokenizer = AutoTokenizer.from_pretrained(model_id)
model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype="auto", device_map="auto")

messages = [
    {"role": "system", "content": "You are a helpful coding assistant."},
    {"role": "user", "content": "Write a Python function to find the longest common subsequence of two strings."},
]

text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
inputs = tokenizer([text], return_tensors="pt").to(model.device)

outputs = model.generate(**inputs, max_new_tokens=2048, temperature=0.6, top_p=0.95, top_k=20)
print(tokenizer.decode(outputs[0][inputs.input_ids.shape[-1]:], skip_special_tokens=True))
```

### vLLM

```bash
vllm serve Tesslate/OmniCoder-9B --tensor-parallel-size 1 --max-model-len 65536
```

```python
from openai import OpenAI

client = OpenAI(base_url="http://localhost:8000/v1", api_key="token")
response = client.chat.completions.create(
    model="Tesslate/OmniCoder-9B",
    messages=[{"role": "user", "content": "Explain the difference between a mutex and a semaphore."}],
    temperature=0.6,
)
print(response.choices[0].message.content)
```

### llama.cpp (GGUF)

```bash
llama-cli --hf-repo Tesslate/OmniCoder-9B-GGUF --hf-file omnicoder-9b-q4_k_m.gguf -p "Your prompt" -c 8192
```

All quantizations: [Tesslate/OmniCoder-9B-GGUF](https://huggingface.co/Tesslate/OmniCoder-9B-GGUF)

---

## Training Details

|  |  |
| :-- | :-- |
| **Base Model** | [Qwen3.5-9B](https://huggingface.co/Qwen/Qwen3.5-9B) |
| **Method** | LoRA SFT (r=64, alpha=32) |
| **Dataset** | 425K agentic trajectories from 5 sources |
| **Packing** | Sample packing with 99.35% efficiency |
| **Hardware** | 4x NVIDIA H200 (DDP) |
| **Framework** | Axolotl |
| **Precision** | bf16 |
| **Optimizer** | AdamW (lr=2e-4, cosine schedule) |

---

## Architecture

OmniCoder inherits Qwen3.5-9B's hybrid architecture:

-   **Gated Delta Networks**: Linear attention layers interleaved with standard attention for efficient long-range dependencies
-   **VLM Backbone**: Built on `Qwen3_5ForConditionalGeneration`

---

## Recommended Sampling Parameters

| Parameter | Value |
| :-- | :-- |
| Temperature | 0.6 |
| Top-P | 0.95 |
| Top-K | 20 |
| Presence Penalty | 0.0 |

For agentic / tool-calling tasks, consider lower temperature (0.2-0.4) for more deterministic behavior.

---

## Limitations

-   Performance on non-English tasks has not been extensively evaluated
-   Tool-calling format is flexible but works best with the scaffolding patterns seen in training

---

## Acknowledgments

Special thanks to the [Axolotl](https://github.com/axolotl-ai-cloud/axolotl) team and the discussion in [axolotl#3453](https://github.com/axolotl-ai-cloud/axolotl/issues/3453) for helping get Qwen3.5 packing support working.

---

## Citation

```
@misc{omnicoder2025,
  title={OmniCoder-9B: A Frontier Open Coding Agent},
  author={Tesslate},
  year={2025},
  url={https://huggingface.co/Tesslate/OmniCoder-9B}
}
```

---

**Built by [Tesslate](https://tesslate.com)**

Downloads last month

8,213

Safetensors

Model size

9B params

Tensor type

BF16

·

## Model tree for Tesslate/OmniCoder-9B

## Collection including Tesslate/OmniCoder-9B

## Evaluation results

-   pass@5 on AIME 2025
    
    [self-reported](/Tesslate/OmniCoder-9B/blob/main/README.md)
    
    90.000
    
-   pass@1 on GPQA Diamond
    
    [self-reported](/Tesslate/OmniCoder-9B/blob/main/README.md)
    
    83.800
    
-   pass@3 on GPQA Diamond
    
    [self-reported](/Tesslate/OmniCoder-9B/blob/main/README.md)
    
    86.400
    
-   Pass Rate on Terminal-Bench 2.0
    
    [self-reported](/Tesslate/OmniCoder-9B/blob/main/README.md)
    
    28.100