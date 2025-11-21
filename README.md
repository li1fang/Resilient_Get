# rget (Resilient Get) 🛡️

> **A standalone, stateful, self-healing downloader for harsh environments.**
>
> **面向受限与恶劣网络环境的无依赖、有状态、自愈系下载工具。**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/language-Bash-green.svg)]()
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20K8s%20COS-lightgrey)]()

---

## 📖 Overview (简介)

**rget** is designed for environments where dependencies like `jq` or `python` are missing (e.g., Kubernetes Init Containers, GKE COS, Alpine) and network reliability is not guaranteed.

It implements a **Stateful Waterfall Strategy** to ensure the file is downloaded, no matter what:

**rget** 专为缺乏 `jq` 或 `python` 等依赖的受限环境（如 Kubernetes Init Containers, GKE COS, Alpine）设计。针对不稳定的网络环境，它实现了一套**有状态的瀑布流策略**，以确保文件下载成功率最大化。

### 🌊 The Waterfall Logic (核心逻辑)

```mermaid
graph TD
    Start[Start] --> CheckState{State Exists?}
    CheckState -- Yes --> ReadHistory[Read Last Success URL]
    CheckState -- No --> Dynamic[Strategy A: Dynamic Resolution]
    
    ReadHistory --> Dynamic
    
    Dynamic -- Success --> DownloadA[Download & Verify]
    Dynamic -- Fail --> History[Strategy B: History Replay]
    
    History -- Success --> DownloadB[Download & Verify]
    History -- Fail --> Fallback[Strategy C: Hard Fallback]
    
    Fallback -- Success --> DownloadC[Download & Verify]
    Fallback -- Fail --> Fatal[Exit 1]
    
    DownloadA --> UpdateState[Update State File]
    DownloadB --> UpdateState
    DownloadC --> UpdateState
    
    UpdateState --> Exit[Exit 0]


Dynamic Resolution (最新策略): Tries to fetch the latest version via a command pipeline.
History Replay (历史回放): If dynamic fails, retries the URL that worked last time (from state file).
Hard Fallback (硬兜底): If all else fails, uses a hardcoded stable URL.

✨ Key Features (特性)

Zero Dependency (零依赖): Pure Bash. Only needs curl OR wget, and standard text tools (grep, sed, awk).
Stateful Persistence (状态持久化): Supports custom state file paths via CLI or Env Var, enabling persistence across Pod restarts.
Idempotency (幂等性): If the file exists and matches the provided SHA256, it skips downloading to save bandwidth.
Non-Interactive (静默模式): Designed for automation. Logs to stderr, exits 0 or 1.

🚀 Usage (使用方法)


Interface


Bash


./rget.sh [OPTIONS] <TARGET_PATH>


Option
Description
说明
--name <ID>
Required. Unique key for the state file.
必填。状态文件中的唯一标识键。
--dynamic-cmd <STR>
Shell pipeline to fetch the latest URL.
用于获取最新 URL 的 Shell 命令管道。
--fallback-url <URL>
Stable backup URL.
稳定的兜底 URL。
--manual-url <URL>
Force download from this URL (Bypass all).
强制指定 URL（跳过所有策略）。
--hash <SHA256>
Expected hash for verification.
期望的 SHA256 哈希值（用于校验）。
--state-file <PATH>
Custom path to state file (Default: ~/.rget.state).
自定义状态文件路径。


Environment Variables (环境变量)

You can also configure the state file location globally:
你也可以通过环境变量全局配置状态文件位置：
RGET_STATE_FILE: Overrides the default location (Same effect as --state-file).

🔥 Examples (实战示例)


1. GKE/Kubernetes Scenario (GKE 场景)

Downloading a WasmEdge shim in a GKE Init Container.
Crucial: Note the use of --state-file (or RGET_STATE_FILE) pointing to a host-mounted directory (/node/...). This ensures the tool "remembers" successful URLs even if the Pod is recreated.
在 GKE 初始化容器中下载 WasmEdge shim。
关键点： 注意使用了 --state-file 指向宿主机挂载目录 (/node/...)。这确保了即使 Pod 重建，工具依然能“记住”成功的 URL。

Bash


# Using CLI Option
./rget.sh \
  --name "wasm-shim" \
  --state-file "/node/home/kubernetes/bin/rget.state" \
  --dynamic-cmd "curl -s [https://api.github.com/repos/containerd/runwasi/releases/latest](https://api.github.com/repos/containerd/runwasi/releases/latest) | grep browser_download_url | grep musl | cut -d '\"' -f 4 | head -n1" \
  --fallback-url "[https://github.com/containerd/runwasi/releases/download/containerd-shim-wasmedge/v0.6.0/containerd-shim-wasmedge-x86_64-linux-musl.tar.gz](https://github.com/containerd/runwasi/releases/download/containerd-shim-wasmedge/v0.6.0/containerd-shim-wasmedge-x86_64-linux-musl.tar.gz)" \
  --hash "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" \
  /home/kubernetes/bin/shim.tar.gz



2. Manual Override (手动强制模式)


Bash


./rget.sh \
  --name "wasm-shim" \
  --manual-url "[https://example.com/stable/shim.tar.gz](https://example.com/stable/shim.tar.gz)" \
  /tmp/shim.tar.gz



🛠️ Testing (测试)

The repository includes a mock test suite covering dynamic resolution, fallback logic, and custom state paths.
仓库包含一个模拟测试套件，覆盖了动态解析、兜底逻辑以及自定义状态路径测试。

Bash


bash ./test.sh



⚖️ License

MIT License.
Order out of Chaos.
