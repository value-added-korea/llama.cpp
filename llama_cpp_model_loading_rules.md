[2606031200:R1]

**1) Verification basis**
All claims below are drawn from Unsloth's documentation, Bartowski's HuggingFace model cards, and llama.cpp/community sources cited inline.

**2) Critical differences (what each one actually does)**

Bartowski — *imatrix + selective embed/output upcast, fixed-scheme*:
- Every quant is built with an **importance matrix (imatrix)** computed from a calibration dataset (the kalomaze/Dampf dataset plus synthetic augmentation). Bartowski credits kalomaze and Dampf for the imatrix calibration dataset, and all quants are made using the imatrix option. The imatrix weights the quantization error toward tensors that matter most for activations.
- His `*_K_L` / `*_K_XL` variants are otherwise-standard K-quants but with **embeddings and output weights bumped to Q8_0**. Quants like Q3_K_XL and Q4_K_L are the standard method with embeddings and output weights quantized to Q8_0 instead of their normal default.
- The bit-width per tensor is essentially the standard llama.cpp scheme for the chosen quant type; the imatrix changes *rounding*, not *which type each layer gets*.

Unsloth — *Dynamic 2.0: per-layer/per-tensor variable bit-width + template/tokenizer fixes*:
- Instead of applying uniform quantization across all layers, Dynamic 2.0 analyzes each individual layer and picks the quantization type that minimizes accuracy loss for that layer. It uses the same quant types as Bartowski and others, but decides per layer and per matrix which type to use, differently from the default GGUF code.
- It is also imatrix-based, but with a **different, larger calibration set** aimed at chat/long-context/tool-calling rather than wiki-text. Unsloth uses Calibration_v3 and Calibration_v5 datasets, noting that text-only calibration is not effective for instruct models and that most imatrix GGUFs are calibrated with those issues. They warn this can make their PPL look *higher* on wiki-test even when KLD is lower. Their imatrix uses long-context chat and tool-calling examples, so their GGUFs sometimes show higher perplexity on the standard Wiki-test.
- Crucially, Unsloth ships **fixed chat templates and tokenizer fixes** (e.g. corrected pad tokens, `<think>` handling). The Unsloth QwQ-32B card notes a tokenizer pad-token fix that mainly affects fine-tuning; on the same quant level file sizes are identical to Bartowski's. The `UD-` prefix marks true dynamic quants; non-UD Unsloth files still use their calibration set but are not dynamic.

Net: Bartowski = imatrix + a couple of high-precision tensors, fixed bit-scheme. Unsloth = imatrix + genuinely *variable* per-tensor bit allocation + packaged template/tokenizer corrections. Note Unsloth's benchmark claims are self-published and calibration-sensitive, so treat "outperforms imatrix" as their measurement, not an independent consensus.

**3) Best category for llama.cpp on Vulkan → K-quants; Unsloth Dynamic K-quants (`*_K_XL`) are the best fit, Bartowski K-quants also fine. Avoid I-quants.**
- Bartowski's own cards repeatedly warn that **I-quants are poorly supported on Vulkan**. The I-quants are flagged as not compatible with Vulkan (AMD), with advice to use a ROCm/rocBLAS build instead if on AMD. Even where Vulkan now technically runs I-quants, they are typically much slower. On Vulkan/SYCL Battlemage, IQ4_NL is ~4x slower than the same-size Q4_0.
- K-quants run well on Vulkan and Unsloth's dynamic K-quants are routinely benchmarked there. A standalone llama.cpp Vulkan run of a Gemma UD-Q4_K_XL model reached 52+ t/s on AMD.
- So on Vulkan: pick a `Q4_K_XL`/`Q5_K_*`-style K-quant. Unsloth's dynamic K-quant gives the better quality-per-byte while staying in the format Vulkan handles efficiently; Bartowski's K-quants are an equally safe choice.

**4) Best category for an Nvidia dGPU (CUDA) → I-quants become viable, so this is the category that shines; both providers' IQ quants work well.**
- CUDA has mature I-quant kernels, so the speed penalty that hurts Vulkan/CPU/Metal largely disappears. The ik_llama.cpp project states the only fully functional, performant backends are CPU (AVX2+) and CUDA (Turing or newer), and steers ROCm/Vulkan/Metal users away.
- This means on Nvidia you can use **I-quants (IQ2_XXS, IQ3_XS, IQ4_XS, UD-IQ\*)** to fit more model per GB of VRAM at good speed. Bartowski's IQ line is the classic, widely-validated choice; Unsloth's `UD-IQ*` dynamic quants are the higher-quality-per-byte option by their benchmarks. One caveat for Nvidia users on the ik_llama.cpp fork specifically: do not use Unsloth `_XL` quants that contain f16 tensors, as they may not work with ik_llama.cpp. On mainline llama.cpp + CUDA, both are fine.

**5) Parameters that MUST/SHOULD be set to utilize each provider's optimization**

Core principle: the quantization itself is baked into the `.gguf`; no runtime flag "switches on" the imatrix or the dynamic bit-allocation. What you *must* set is the small group of flags that (a) load the correct chat template the quant was tuned with, (b) place tensors so a dynamic/MoE quant performs as designed, and (c) match the sampler defaults the publisher tuned. Below, parameter names reference the project file `llama-cpp_parameters.md`.

| [2606031200:R1:T3] Param | Unsloth | Why / source |
|---|---|---|
| `--jinja` | **MUST** | Activates Unsloth's *fixed* chat template. Unsloth states you must use `--jinja`; without it the output will be wrong because their fixed templates aren't applied. For Devstral, `--jinja` is required to enable the system prompt. |
| `--chat-template-file` / `--chat-template` | SHOULD (fallback) | Use only if your llama.cpp build predates their template fix; otherwise `--jinja` reads the embedded fixed template. |
| `--samplers "..."` + `--temp/--top-p/--top-k/--min-p/--repeat-penalty` | **MUST match shipped params** | Unsloth bundles suggested parameters (temperature etc.) in a `params` file in the HF upload. For reasoning models, the sampler *order* matters. Unsloth's QwQ fix is `--samplers "top_k;top_p;min_p;temperature;dry;typ_p;xtc"`, and they warn llama.cpp defaults min_p to 0.1, which must be lowered (e.g. `--min-p 0.01`). |
| `-ot`/`--override-tensor` or `-cmoe`/`--cpu-moe` / `-ncmoe`/`--n-cpu-moe` | MUST for big MoE dynamic quants | Unsloth's Llama-4 run uses `-ot ".ffn_.*_exps.=CPU"` to keep expert tensors on CPU. Lets a dynamic MoE quant fit and run at intended speed. |
| `-fa`/`--flash-attn on` + `-ctk`/`-ctv` (`--cache-type-k/-v`) | SHOULD (long ctx) | For KV-cache quantization Unsloth says compile with `-DGGML_CUDA_FA_ALL_QUANTS=ON`, enable `--flash-attn`, then set `--cache-type-k`/`--cache-type-v` (q8_0, q4_0, etc.). |
| `-fit`/`--fit on` | SHOULD | Unsloth recommends `--fit on` to auto-maximize GPU usage. |
| `-ngl`/`--gpu-layers`, `-c`/`--ctx-size` | MUST (sizing) | Standard offload/context sizing per their per-model guides. |

| [2606031200:R1:T3] Param | Bartowski | Why / source |
|---|---|---|
| (chat template) `--jinja` or model's own template | SHOULD | Bartowski quants carry the model's stock template; he documents the exact prompt format on each card. No proprietary fix to enable, but the right template still matters. |
| `-ngl`/`--gpu-layers`, `-c`/`--ctx-size`, `-b`/`-ub` | MUST (sizing) | His sizing guidance: fit the whole quant in VRAM 1–2 GB under capacity for speed, or add system RAM for max quality, and choose K-quant vs I-quant accordingly. |
| `-ctk`/`-ctv`, `-fa` | SHOULD | Same KV/flash-attn levers as any imatrix quant; nothing Bartowski-specific. |
| backend build (CUDA vs Vulkan/ROCm) — not a flag but the key choice | **MUST** | His cards warn I-quants are not Vulkan-compatible; on AMD use a rocBLAS/ROCm build. Pick the quant *type* to match the backend (I-quant→CUDA, K-quant→Vulkan/CPU). |
| `--override-kv` | OPTIONAL | Only to patch metadata; his embed/output-Q8_0 (`*_K_L/_XL`) need no special flag. |

Shared backend/perf parameters that interact with either provider's quant (from the project file): `-t`/`--threads`, `-tb`/`--threads-batch`, `--prio`, `-sm`/`--split-mode` and `-ts`/`--tensor-split` (multi-GPU), `-mg`/`--main-gpu`, `--mmap`/`--no-mmap` (Unsloth GLM guide uses `--no-mmap` for RAM-resident MoE), `--mlock`, `-np`/`--parallel`, `-cb`/`--cont-batching`, `--reasoning-format auto` and `-rea`/`--reasoning` (for thinking models), and `--reasoning-budget`. None of these *enable* the quant optimization; they tune throughput/placement around it.

Single most important takeaway: for **Unsloth**, `--jinja` plus the shipped sampler params is the non-negotiable pair — skip them and you lose the template/tokenizer fixes that are half of what Dynamic 2.0 buys you. For **Bartowski**, there is no activation flag; the only "must" is choosing the quant *type* to match your backend (I-quant on CUDA, K-quant on Vulkan) and applying the model's correct prompt template.
