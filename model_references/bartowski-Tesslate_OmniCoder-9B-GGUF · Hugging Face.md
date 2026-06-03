---
title: bartowski/Tesslate_OmniCoder-9B-GGUF · Hugging Face
description: We’re on a journey to advance and democratize artificial intelligence through open source and open science.
source: "https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF"
site: huggingface.co
saved: "2026-06-03T03:50:27.477Z"
---
## Llamacpp imatrix Quantizations of OmniCoder-9B by Tesslate

Using [llama.cpp](https://github.com/ggml-org/llama.cpp/) release for quantization.

Original model: [https://huggingface.co/Tesslate/OmniCoder-9B](https://huggingface.co/Tesslate/OmniCoder-9B)

All quants made using imatrix option with dataset from [here](https://gist.github.com/bartowski1182/82ae9b520227f57d79ba04add13d0d0d)

Run them in your choice of tools:

-   [llama.cpp](https://github.com/ggml-org/llama.cpp)
-   [LM Studio](https://lmstudio.ai/)
-   [koboldcpp](https://github.com/LostRuins/koboldcpp)
-   [Jan AI](https://www.jan.ai/)
-   [Text Generation Web UI](https://github.com/oobabooga/text-generation-webui)
-   [LoLLMs](https://github.com/ParisNeo/lollms)

Note: if it's a newly supported model, you may need to wait for an update from the developers.

## Prompt format

```
<|im_start|>system
{system_prompt}<|im_end|>
<|im_start|>user
{prompt}<|im_end|>
<|im_start|>assistant
<think>
```

## Download a file (not the whole branch) from below:

| Filename | Quant type | File Size | Split | Description |
| --- | --- | --- | --- | --- |
| [OmniCoder-9B-bf16.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-bf16.gguf) | bf16 | 17.92GB | false | Full BF16 weights. |
| [OmniCoder-9B-Q8\_0.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q8_0.gguf) | Q8\_0 | 9.55GB | false | Extremely high quality, generally unneeded but max available quant. |
| [OmniCoder-9B-Q6\_K\_L.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q6_K_L.gguf) | Q6\_K\_L | 8.19GB | false | Uses Q8\_0 for embed and output weights. Very high quality, near perfect, *recommended*. |
| [OmniCoder-9B-Q6\_K.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q6_K.gguf) | Q6\_K | 7.70GB | false | Very high quality, near perfect, *recommended*. |
| [OmniCoder-9B-Q5\_K\_L.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q5_K_L.gguf) | Q5\_K\_L | 7.48GB | false | Uses Q8\_0 for embed and output weights. High quality, *recommended*. |
| [OmniCoder-9B-Q5\_K\_M.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q5_K_M.gguf) | Q5\_K\_M | 6.85GB | false | High quality, *recommended*. |
| [OmniCoder-9B-Q4\_K\_L.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q4_K_L.gguf) | Q4\_K\_L | 6.67GB | false | Uses Q8\_0 for embed and output weights. Good quality, *recommended*. |
| [OmniCoder-9B-Q5\_K\_S.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q5_K_S.gguf) | Q5\_K\_S | 6.53GB | false | High quality, *recommended*. |
| [OmniCoder-9B-Q3\_K\_XL.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q3_K_XL.gguf) | Q3\_K\_XL | 6.00GB | false | Uses Q8\_0 for embed and output weights. Lower quality but usable, good for low RAM availability. |
| [OmniCoder-9B-Q4\_1.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q4_1.gguf) | Q4\_1 | 5.94GB | false | Legacy format, similar performance to Q4\_K\_S but with improved tokens/watt on Apple silicon. |
| [OmniCoder-9B-Q4\_K\_M.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q4_K_M.gguf) | Q4\_K\_M | 5.91GB | false | Good quality, default size for most use cases, *recommended*. |
| [OmniCoder-9B-Q4\_K\_S.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q4_K_S.gguf) | Q4\_K\_S | 5.60GB | false | Slightly lower quality with more space savings, *recommended*. |
| [OmniCoder-9B-Q4\_0.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q4_0.gguf) | Q4\_0 | 5.48GB | false | Legacy format, offers online repacking for ARM and AVX CPU inference. |
| [OmniCoder-9B-IQ4\_NL.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-IQ4_NL.gguf) | IQ4\_NL | 5.48GB | false | Similar to IQ4\_XS, but slightly larger. Offers online repacking for ARM CPU inference. |
| [OmniCoder-9B-IQ4\_XS.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-IQ4_XS.gguf) | IQ4\_XS | 5.24GB | false | Decent quality, smaller than Q4\_K\_S with similar performance, *recommended*. |
| [OmniCoder-9B-Q3\_K\_L.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q3_K_L.gguf) | Q3\_K\_L | 5.11GB | false | Lower quality but usable, good for low RAM availability. |
| [OmniCoder-9B-Q2\_K\_L.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q2_K_L.gguf) | Q2\_K\_L | 5.06GB | false | Uses Q8\_0 for embed and output weights. Very low quality but surprisingly usable. |
| [OmniCoder-9B-Q3\_K\_M.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q3_K_M.gguf) | Q3\_K\_M | 4.92GB | false | Low quality. |
| [OmniCoder-9B-IQ3\_M.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-IQ3_M.gguf) | IQ3\_M | 4.72GB | false | Medium-low quality, new method with decent performance comparable to Q3\_K\_M. |
| [OmniCoder-9B-Q3\_K\_S.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q3_K_S.gguf) | Q3\_K\_S | 4.67GB | false | Low quality, not recommended. |
| [OmniCoder-9B-IQ3\_XS.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-IQ3_XS.gguf) | IQ3\_XS | 4.56GB | false | Lower quality, new method with decent performance, slightly better than Q3\_K\_S. |
| [OmniCoder-9B-IQ3\_XXS.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-IQ3_XXS.gguf) | IQ3\_XXS | 4.28GB | false | Lower quality, new method with decent performance, comparable to Q3 quants. |
| [OmniCoder-9B-Q2\_K.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-Q2_K.gguf) | Q2\_K | 4.06GB | false | Very low quality but surprisingly usable. |
| [OmniCoder-9B-IQ2\_M.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-IQ2_M.gguf) | IQ2\_M | 3.77GB | false | Relatively low quality, uses SOTA techniques to be surprisingly usable. |
| [OmniCoder-9B-IQ2\_S.gguf](https://huggingface.co/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/Tesslate_OmniCoder-9B-IQ2_S.gguf) | IQ2\_S | 3.61GB | false | Low quality, uses SOTA techniques to be usable. |

## Embed/output weights

Some of these quants (Q3\_K\_XL, Q4\_K\_L etc) are the standard quantization method with the embeddings and output weights quantized to Q8\_0 instead of what they would normally default to.

## Downloading using huggingface-cli

Click to view download instructions

First, make sure you have hugginface-cli installed:

```
pip install -U "huggingface_hub[cli]"
```

Then, you can target the specific file you want:

```
huggingface-cli download bartowski/Tesslate_OmniCoder-9B-GGUF --include "Tesslate_OmniCoder-9B-Q4_K_M.gguf" --local-dir ./
```

If the model is bigger than 50GB, it will have been split into multiple files. In order to download them all to a local folder, run:

```
huggingface-cli download bartowski/Tesslate_OmniCoder-9B-GGUF --include "Tesslate_OmniCoder-9B-Q8_0/*" --local-dir ./
```

You can either specify a new local-dir (Tesslate\_OmniCoder-9B-Q8\_0) or download them all in place (./)

## ARM/AVX information

Previously, you would download Q4\_0\_4\_4/4\_8/8\_8, and these would have their weights interleaved in memory in order to improve performance on ARM and AVX machines by loading up more data in one pass.

Now, however, there is something called "online repacking" for weights. details in [this PR](https://github.com/ggml-org/llama.cpp/pull/9921). If you use Q4\_0 and your hardware would benefit from repacking weights, it will do it automatically on the fly.

As of llama.cpp build you will not be able to run the Q4\_0\_X\_X files and will instead need to use Q4\_0.

Additionally, if you want to get slightly better quality for, you can use IQ4\_NL thanks to [this PR](https://github.com/ggml-org/llama.cpp/pull/10541) which will also repack the weights for ARM, though only the 4\_4 for now. The loading time may be slower but it will result in an overall speed incrase.

Click to view Q4\_0\_X\_X information (deprecated

I'm keeping this section to show the potential theoretical uplift in performance from using the Q4\_0 with online repacking.

Click to view benchmarks on an AVX2 system (EPYC7702)

| model | size | params | backend | threads | test | t/s | % (vs Q4\_0) |
| --- | --: | --: | --- | --: | --: | --: | --: |
| qwen2 3B Q4\_0 | 1.70 GiB | 3.09 B | CPU | 64 | pp512 | 204.03 ± 1.03 | 100% |
| qwen2 3B Q4\_0 | 1.70 GiB | 3.09 B | CPU | 64 | pp1024 | 282.92 ± 0.19 | 100% |
| qwen2 3B Q4\_0 | 1.70 GiB | 3.09 B | CPU | 64 | pp2048 | 259.49 ± 0.44 | 100% |
| qwen2 3B Q4\_0 | 1.70 GiB | 3.09 B | CPU | 64 | tg128 | 39.12 ± 0.27 | 100% |
| qwen2 3B Q4\_0 | 1.70 GiB | 3.09 B | CPU | 64 | tg256 | 39.31 ± 0.69 | 100% |
| qwen2 3B Q4\_0 | 1.70 GiB | 3.09 B | CPU | 64 | tg512 | 40.52 ± 0.03 | 100% |
| qwen2 3B Q4\_K\_M | 1.79 GiB | 3.09 B | CPU | 64 | pp512 | 301.02 ± 1.74 | 147% |
| qwen2 3B Q4\_K\_M | 1.79 GiB | 3.09 B | CPU | 64 | pp1024 | 287.23 ± 0.20 | 101% |
| qwen2 3B Q4\_K\_M | 1.79 GiB | 3.09 B | CPU | 64 | pp2048 | 262.77 ± 1.81 | 101% |
| qwen2 3B Q4\_K\_M | 1.79 GiB | 3.09 B | CPU | 64 | tg128 | 18.80 ± 0.99 | 48% |
| qwen2 3B Q4\_K\_M | 1.79 GiB | 3.09 B | CPU | 64 | tg256 | 24.46 ± 3.04 | 83% |
| qwen2 3B Q4\_K\_M | 1.79 GiB | 3.09 B | CPU | 64 | tg512 | 36.32 ± 3.59 | 90% |
| qwen2 3B Q4\_0\_8\_8 | 1.69 GiB | 3.09 B | CPU | 64 | pp512 | 271.71 ± 3.53 | 133% |
| qwen2 3B Q4\_0\_8\_8 | 1.69 GiB | 3.09 B | CPU | 64 | pp1024 | 279.86 ± 45.63 | 100% |
| qwen2 3B Q4\_0\_8\_8 | 1.69 GiB | 3.09 B | CPU | 64 | pp2048 | 320.77 ± 5.00 | 124% |
| qwen2 3B Q4\_0\_8\_8 | 1.69 GiB | 3.09 B | CPU | 64 | tg128 | 43.51 ± 0.05 | 111% |
| qwen2 3B Q4\_0\_8\_8 | 1.69 GiB | 3.09 B | CPU | 64 | tg256 | 43.35 ± 0.09 | 110% |
| qwen2 3B Q4\_0\_8\_8 | 1.69 GiB | 3.09 B | CPU | 64 | tg512 | 42.60 ± 0.31 | 105% |

Q4\_0\_8\_8 offers a nice bump to prompt processing and a small bump to text generation

## Which file should I choose?

Click here for details

A great write up with charts showing various performances is provided by Artefact2 [here](https://gist.github.com/Artefact2/b5f810600771265fc1e39442288e8ec9)

The first thing to figure out is how big a model you can run. To do this, you'll need to figure out how much RAM and/or VRAM you have.

If you want your model running as FAST as possible, you'll want to fit the whole thing on your GPU's VRAM. Aim for a quant with a file size 1-2GB smaller than your GPU's total VRAM.

If you want the absolute maximum quality, add both your system RAM and your GPU's VRAM together, then similarly grab a quant with a file size 1-2GB Smaller than that total.

Next, you'll need to decide if you want to use an 'I-quant' or a 'K-quant'.

If you don't want to think too much, grab one of the K-quants. These are in format 'QX\_K\_X', like Q5\_K\_M.

If you want to get more into the weeds, you can check out this extremely useful feature chart:

[llama.cpp feature matrix](https://github.com/ggml-org/llama.cpp/wiki/Feature-matrix)

But basically, if you're aiming for below Q4, and you're running cuBLAS (Nvidia) or rocBLAS (AMD), you should look towards the I-quants. These are in format IQX\_X, like IQ3\_M. These are newer and offer better performance for their size.

These I-quants can also be used on CPU, but will be slower than their K-quant equivalent, so speed vs performance is a tradeoff you'll have to decide.

## Credits

Thank you kalomaze and Dampf for assistance in creating the imatrix calibration dataset.

Thank you ZeroWw for the inspiration to experiment with embed/output.

Thank you to LM Studio for sponsoring my work.

Want to support my work? Visit my ko-fi page here: [https://ko-fi.com/bartowski](https://ko-fi.com/bartowski)

Downloads last month

2,195

GGUF

Model size

9B params

Architecture

qwen35

Hardware compatibility

[Log In](/login?next=https%3A%2F%2Fhuggingface.co%2Fbartowski%2FTesslate_OmniCoder-9B-GGUF) to add your hardware

2-bit

3-bit

4-bit

5-bit

6-bit

8-bit

16-bit

[View +1 variant](/bartowski/Tesslate_OmniCoder-9B-GGUF/tree/main)

## Model tree for bartowski/Tesslate\_OmniCoder-9B-GGUF

Base model

[Qwen/Qwen3.5-9B-Base](/Qwen/Qwen3.5-9B-Base)

Finetuned

[Qwen/Qwen3.5-9B](/Qwen/Qwen3.5-9B)

Finetuned

[Tesslate/OmniCoder-9B](/Tesslate/OmniCoder-9B)

Quantized

([19](/models?other=base_model:quantized:Tesslate/OmniCoder-9B))

this model

## Evaluation results

-   pass@5 on AIME 2025
    
    [self-reported](/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/README.md)
    
    90.000
    
-   pass@1 on AIME 2025
    
    [self-reported](/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/README.md)
    
    83.800
    
-   pass@3 on AIME 2025
    
    [self-reported](/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/README.md)
    
    86.400
    
-   Pass Rate on AIME 2025
    
    [self-reported](/bartowski/Tesslate_OmniCoder-9B-GGUF/blob/main/README.md)
    
    28.100