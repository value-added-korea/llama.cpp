---
title: bartowski/Qwen2.5-Coder-7B-Instruct-GGUF · Hugging Face
description: We’re on a journey to advance and democratize artificial intelligence through open source and open science.
source: "https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF"
site: huggingface.co
saved: "2026-06-02T23:17:23.136Z"
---
## Llamacpp imatrix Quantizations of Qwen2.5-Coder-7B-Instruct

Using [llama.cpp](https://github.com/ggerganov/llama.cpp/) release for quantization.

Original model: [https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct](https://huggingface.co/Qwen/Qwen2.5-Coder-7B-Instruct)

All quants made using imatrix option with dataset from [here](https://gist.github.com/bartowski1182/eb213dccb3571f863da82e99418f81e8)

Run them in [LM Studio](https://lmstudio.ai/)

## Prompt format

```
<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
{prompt}<|im_end|>
<|im_start|>assistant
```

## What's new:

Update context length configuration and tokenizer

## Download a file (not the whole branch) from below:

| Filename | Quant type | File Size | Split | Description |
| --- | --- | --- | --- | --- |
| [Qwen2.5-Coder-7B-Instruct-f16.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-f16.gguf) | f16 | 15.24GB | false | Full F16 weights. |
| [Qwen2.5-Coder-7B-Instruct-Q8\_0.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q8_0.gguf) | Q8\_0 | 8.10GB | false | Extremely high quality, generally unneeded but max available quant. |
| [Qwen2.5-Coder-7B-Instruct-Q6\_K\_L.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q6_K_L.gguf) | Q6\_K\_L | 6.52GB | false | Uses Q8\_0 for embed and output weights. Very high quality, near perfect, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q6\_K.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q6_K.gguf) | Q6\_K | 6.25GB | false | Very high quality, near perfect, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q5\_K\_L.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q5_K_L.gguf) | Q5\_K\_L | 5.78GB | false | Uses Q8\_0 for embed and output weights. High quality, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q5\_K\_M.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q5_K_M.gguf) | Q5\_K\_M | 5.44GB | false | High quality, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q5\_K\_S.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q5_K_S.gguf) | Q5\_K\_S | 5.32GB | false | High quality, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q4\_K\_L.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q4_K_L.gguf) | Q4\_K\_L | 5.09GB | false | Uses Q8\_0 for embed and output weights. Good quality, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q4\_K\_M.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf) | Q4\_K\_M | 4.68GB | false | Good quality, default size for must use cases, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q3\_K\_XL.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q3_K_XL.gguf) | Q3\_K\_XL | 4.57GB | false | Uses Q8\_0 for embed and output weights. Lower quality but usable, good for low RAM availability. |
| [Qwen2.5-Coder-7B-Instruct-Q4\_K\_S.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q4_K_S.gguf) | Q4\_K\_S | 4.46GB | false | Slightly lower quality with more space savings, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q4\_0.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q4_0.gguf) | Q4\_0 | 4.44GB | false | Legacy format, generally not worth using over similarly sized formats |
| [Qwen2.5-Coder-7B-Instruct-Q4\_0\_8\_8.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q4_0_8_8.gguf) | Q4\_0\_8\_8 | 4.43GB | false | Optimized for ARM inference. Requires 'sve' support (see link below). |
| [Qwen2.5-Coder-7B-Instruct-Q4\_0\_4\_8.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q4_0_4_8.gguf) | Q4\_0\_4\_8 | 4.43GB | false | Optimized for ARM inference. Requires 'i8mm' support (see link below). |
| [Qwen2.5-Coder-7B-Instruct-Q4\_0\_4\_4.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q4_0_4_4.gguf) | Q4\_0\_4\_4 | 4.43GB | false | Optimized for ARM inference. Should work well on all ARM chips, pick this if you're unsure. |
| [Qwen2.5-Coder-7B-Instruct-IQ4\_XS.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-IQ4_XS.gguf) | IQ4\_XS | 4.22GB | false | Decent quality, smaller than Q4\_K\_S with similar performance, *recommended*. |
| [Qwen2.5-Coder-7B-Instruct-Q3\_K\_L.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q3_K_L.gguf) | Q3\_K\_L | 4.09GB | false | Lower quality but usable, good for low RAM availability. |
| [Qwen2.5-Coder-7B-Instruct-Q3\_K\_M.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q3_K_M.gguf) | Q3\_K\_M | 3.81GB | false | Low quality. |
| [Qwen2.5-Coder-7B-Instruct-IQ3\_M.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-IQ3_M.gguf) | IQ3\_M | 3.57GB | false | Medium-low quality, new method with decent performance comparable to Q3\_K\_M. |
| [Qwen2.5-Coder-7B-Instruct-Q2\_K\_L.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q2_K_L.gguf) | Q2\_K\_L | 3.55GB | false | Uses Q8\_0 for embed and output weights. Very low quality but surprisingly usable. |
| [Qwen2.5-Coder-7B-Instruct-Q3\_K\_S.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q3_K_S.gguf) | Q3\_K\_S | 3.49GB | false | Low quality, not recommended. |
| [Qwen2.5-Coder-7B-Instruct-IQ3\_XS.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-IQ3_XS.gguf) | IQ3\_XS | 3.35GB | false | Lower quality, new method with decent performance, slightly better than Q3\_K\_S. |
| [Qwen2.5-Coder-7B-Instruct-Q2\_K.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-Q2_K.gguf) | Q2\_K | 3.02GB | false | Very low quality but surprisingly usable. |
| [Qwen2.5-Coder-7B-Instruct-IQ2\_M.gguf](https://huggingface.co/bartowski/Qwen2.5-Coder-7B-Instruct-GGUF/blob/main/Qwen2.5-Coder-7B-Instruct-IQ2_M.gguf) | IQ2\_M | 2.78GB | false | Relatively low quality, uses SOTA techniques to be surprisingly usable. |

## Embed/output weights

Some of these quants (Q3\_K\_XL, Q4\_K\_L etc) are the standard quantization method with the embeddings and output weights quantized to Q8\_0 instead of what they would normally default to.

Some say that this improves the quality, others don't notice any difference. If you use these models PLEASE COMMENT with your findings. I would like feedback that these are actually used and useful so I don't keep uploading quants no one is using.

Thanks!

## Downloading using huggingface-cli

First, make sure you have hugginface-cli installed:

```
pip install -U "huggingface_hub[cli]"
```

Then, you can target the specific file you want:

```
huggingface-cli download bartowski/Qwen2.5-Coder-7B-Instruct-GGUF --include "Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf" --local-dir ./
```

If the model is bigger than 50GB, it will have been split into multiple files. In order to download them all to a local folder, run:

```
huggingface-cli download bartowski/Qwen2.5-Coder-7B-Instruct-GGUF --include "Qwen2.5-Coder-7B-Instruct-Q8_0/*" --local-dir ./
```

You can either specify a new local-dir (Qwen2.5-Coder-7B-Instruct-Q8\_0) or download them all in place (./)

## Q4\_0\_X\_X

These are *NOT* for Metal (Apple) offloading, only ARM chips.

If you're using an ARM chip, the Q4\_0\_X\_X quants will have a substantial speedup. Check out Q4\_0\_4\_4 speed comparisons [on the original pull request](https://github.com/ggerganov/llama.cpp/pull/5780#pullrequestreview-21657544660)

To check which one would work best for your ARM chip, you can check [AArch64 SoC features](https://gpages.juszkiewicz.com.pl/arm-socs-table/arm-socs.html) (thanks EloyOn!).

## Which file should I choose?

A great write up with charts showing various performances is provided by Artefact2 [here](https://gist.github.com/Artefact2/b5f810600771265fc1e39442288e8ec9)

The first thing to figure out is how big a model you can run. To do this, you'll need to figure out how much RAM and/or VRAM you have.

If you want your model running as FAST as possible, you'll want to fit the whole thing on your GPU's VRAM. Aim for a quant with a file size 1-2GB smaller than your GPU's total VRAM.

If you want the absolute maximum quality, add both your system RAM and your GPU's VRAM together, then similarly grab a quant with a file size 1-2GB Smaller than that total.

Next, you'll need to decide if you want to use an 'I-quant' or a 'K-quant'.

If you don't want to think too much, grab one of the K-quants. These are in format 'QX\_K\_X', like Q5\_K\_M.

If you want to get more into the weeds, you can check out this extremely useful feature chart:

[llama.cpp feature matrix](https://github.com/ggerganov/llama.cpp/wiki/Feature-matrix)

But basically, if you're aiming for below Q4, and you're running cuBLAS (Nvidia) or rocBLAS (AMD), you should look towards the I-quants. These are in format IQX\_X, like IQ3\_M. These are newer and offer better performance for their size.

These I-quants can also be used on CPU and Apple Metal, but will be slower than their K-quant equivalent, so speed vs performance is a tradeoff you'll have to decide.

The I-quants are *not* compatible with Vulcan, which is also AMD, so if you have an AMD card double check if you're using the rocBLAS build or the Vulcan build. At the time of writing this, LM Studio has a preview with ROCm support, and other inference engines have specific builds for ROCm.

## Credits

Thank you kalomaze and Dampf for assistance in creating the imatrix calibration dataset

Thank you ZeroWw for the inspiration to experiment with embed/output

Want to support my work? Visit my ko-fi page here: [https://ko-fi.com/bartowski](https://ko-fi.com/bartowski)

Downloads last month

73,782

GGUF

Model size

8B params

Architecture

qwen2

Hardware compatibility

[Log In](/login?next=https%3A%2F%2Fhuggingface.co%2Fbartowski%2FQwen2.5-Coder-7B-Instruct-GGUF) to add your hardware

2-bit

3-bit

4-bit

5-bit

6-bit

8-bit

16-bit

## Model tree for bartowski/Qwen2.5-Coder-7B-Instruct-GGUF

Base model

[Qwen/Qwen2.5-7B](/Qwen/Qwen2.5-7B)

Finetuned

[Qwen/Qwen2.5-Coder-7B](/Qwen/Qwen2.5-Coder-7B)

Finetuned

[Qwen/Qwen2.5-Coder-7B-Instruct](/Qwen/Qwen2.5-Coder-7B-Instruct)

Quantized

([193](/models?other=base_model:quantized:Qwen/Qwen2.5-Coder-7B-Instruct))

this model