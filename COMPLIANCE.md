# Compliance & Third-Party Notices

`p1xi3` interacts with and orchestrates several open-source tools, runtimes, and machine learning models. This document outlines the licenses and compliance requirements for all associated software and model weights.

---

## 1. Project License

The scripts, tools, and interfaces in this repository are licensed under the **MIT License**. See [LICENSE](LICENSE) for the full text.

---

## 2. Upstream Software Licenses

| Component | Upstream Project | License | Notes |
|---|---|---|---|
| **llama.cpp** | [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | **MIT** | Copyright (c) 2023-2026 Georgi Gerganov & ggml contributors. |
| **Termux** | [termux/termux-app](https://github.com/termux/termux-app) | **GPL-3.0** | Copyright (c) Fredrik Fornwall and contributors. Sideloaded via official APK releases. |
| **GrapheneOS** | [GrapheneOS](https://grapheneos.org) | **GPL-2.0 / Apache-2.0 / MIT** | Upstream hardened Android OS and verified boot implementation. |
| **ADB & Fastboot** | [Android Open Source Project](https://source.android.com) | **Apache-2.0** | Host platform tools from Google/AOSP. |

---

## 3. Curated Model Weight Licenses

Each model architecture and weight file distributed through HuggingFace has its own upstream licensing terms:

### A. Meta Llama 3.2 Models
- **Models**: `Llama-3.2-1B-Instruct`, `Llama-3.2-3B-Instruct`
- **License**: **Llama 3.2 Community License Agreement**
- **Terms Summary**:
  - Permissive commercial and non-commercial use.
  - Attribution: "Built with Llama 3.2".
  - If monthly active users exceed 700 million, a commercial license request from Meta is required.
  - Subject to Meta's Acceptable Use Policy.

### B. Alibaba Qwen 2.5 & Qwen 2.5 Coder
- **Models**: `Qwen2.5-Coder-1.5B-Instruct`, `Qwen2.5-Coder-3B-Instruct`, `Qwen2.5-1.5B-Instruct`
- **License**: **Apache-2.0**
- **Terms Summary**:
  - Permissive open-source license allowing commercial use, modification, distribution, and private use.

### C. DeepSeek Models
- **Models**: `DeepSeek-R1-Distill-Qwen-1.5B`
- **License**: **MIT License**
- **Terms Summary**:
  - Permissive open-source license allowing commercial and non-commercial use without restriction.

### D. Hugging Face SmolLM2 Models
- **Models**: `SmolLM2-1.7B-Instruct`, `SmolLM2-360M-Instruct`
- **License**: **Apache-2.0**
- **Terms Summary**:
  - Permissive open-source license developed by Hugging Face TB.

---

## 4. Air-Gap & Privacy Compliance

- **No Remote Telemetry**: `p1xi3` contains no telemetry, analytics, tracking, or network callbacks.
- **Offline Integrity**: Once models and runtimes are downloaded to the host, all inference is performed on the local device across a physical USB cable without internet transmission.
- **GrapheneOS Hardening**: Revoking network permission on GrapheneOS guarantees hardware and kernel isolation against external socket communication.

---

## 5. Acknowledgments & Upstream Repositories

Special thanks and acknowledgment to the maintainers, researchers, and engineers behind:

- **[ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp)**: Georgi Gerganov and the GGML development team.
- **[GrapheneOS](https://grapheneos.org)**: The GrapheneOS Foundation and security contributors.
- **[Termux](https://github.com/termux/termux-app)**: Fredrik Fornwall and the Termux packaging team.
- **[QwenLM](https://github.com/QwenLM/Qwen2.5)**: Alibaba Cloud's Qwen LLM Research Group.
- **[DeepSeek-AI](https://github.com/deepseek-ai/DeepSeek-R1)**: DeepSeek Artificial Intelligence.
- **[Meta AI Research](https://ai.meta.com/llama/)**: The Meta Llama research and engineering team.
- **[Hugging Face](https://huggingface.co/)**: Loubna Ben Allal, Anton Lozhkov, and the Hugging Face TB team (`SmolLM2`).
- **[Unsloth AI](https://github.com/unslothai/unsloth)**: Daniel Han and the Unsloth team for GGUF distillations and export tooling.
- **[Bartowski](https://huggingface.co/bartowski)**: For high-precision GGUF quantization matrices.
