<div align="center">

# choirboy-prompt

<h3>Lore 注入：被伪造的记忆如何变成模型的信任</h3>

<p>
<strong>阅读其他语言版本</strong><br>
<a href="README.md">🇺🇸 English</a> ·
<a href="README.ru.md">🇷🇺 Русский</a> ·
<a href="README.zh-CN.md">🇨🇳 简体中文</a>
</p>

<p>
<img alt="Bash 5.0+" src="https://img.shields.io/badge/bash-5.0%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white">
<img alt="runtimes" src="https://img.shields.io/badge/runtimes-claude%20%C2%B7%20codex%20%C2%B7%20opencode%20%C2%B7%20hermes%20%C2%B7%20kimi%20%C2%B7%20gemini-22D3EE?style=flat-square">
<a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-3FB950?style=flat-square"></a>
</p>

<p>
choirboy-prompt 是一个双模式研究 harness：Claude Code SessionStart 钩子或
Chat/Cowork skill 注入固定 lore，演示 <em>fabricated-provenance trust</em>
（伪造来源信任）向量：模型把植入的「共同工作」
历史当作自己的记忆，并把信任转移给这段历史所描述的人。
</p>

</div>

<div align="center">
<p>
<a href="#快速开始">快速开始</a> ·
<a href="#必须如何编写自己的-loreresearch论证与-sessions">编写指南</a> ·
<a href="#为什么存在">为什么</a> ·
<a href="#能力地图">能力</a> ·
<a href="#工作原理">原理</a> ·
<a href="#为什么有效">研究</a> ·
<a href="#文档">文档</a> ·
<a href="#已知限制">限制</a>
</p>
</div>

---

## 快速开始

同一个插件现在提供两条上下文投递路径：Claude Code 中自动运行的
`SessionStart` 钩子，以及 Claude Chat/Cowork 中的 **load-context** skill 回退。

### Claude Code CLI

添加仓库 marketplace 并安装插件：

```text
/plugin marketplace add howdeploy/choirboy-prompt
/plugin install choirboy-prompt@choirboy-prompt
```

启动新会话后，钩子会自动注入 lore。使用
`/choirboy-prompt:diagnose` 检查投递，或显式运行
`/choirboy-prompt:load-context`。

通过 CLI 卸载：

```text
/plugin uninstall choirboy-prompt@choirboy-prompt
/plugin marketplace remove choirboy-prompt
```

### Claude Desktop → Code

不要在 Desktop 中发送交互式 `/plugin` 对话命令。前往
**Customize → Plugins → Personal plugins → + → Add marketplace**，添加
`https://github.com/howdeploy/choirboy-prompt`。然后打开本地 Code 会话，选择
**+ → Plugins → Add plugin → choirboy-prompt**，启用后启动一个新会话。

钩子使用 Claude Code 官方的无 shell exec form，并设置 15 秒超时；它仍需要
`bash`。如果 Windows、SSH 或 Cowork 没有启动钩子，请使用内置
load-context skill。

### Claude Chat 与 Cowork

在 **Customize → Plugins** 中把同一仓库安装为 custom plugin，或者上传以下
命令生成的 ZIP：

```bash
python3 scripts/package-plugin.py
```

普通 Chat 不运行 `SessionStart`。请选择 **load-context** skill，或要求 Claude
“load Choirboy context”。Cowork 在钩子可用时使用钩子，并以同一个 skill
作为确定性的回退。

Marketplace 安装与 `./install.sh --target claude` 二选一；如果同时启用，
同一个 `SessionStart` payload 会执行两次。

### 从终端安装

你需要 Linux 或 macOS、`git`、`python3`（`install.sh` 必需），以及六种
受支持运行时中的任意一种。在 Windows 上，此多运行时安装方式使用 WSL。

#### 1. 打开终端

- **macOS**：按 `Cmd + Space`，输入 `Terminal`，回车。
- **Linux**：按 `Ctrl + Alt + T`，或在应用菜单中找到「终端」。
- **Windows**：先安装 [WSL](https://learn.microsoft.com/windows/wsl/install)，
  然后从开始菜单打开「Ubuntu」。以下所有命令都在 WSL 中执行。

#### 2. 安装 git（如果 `git --version` 能打印版本号则跳过）

```bash
# Ubuntu / Debian / WSL:
sudo apt update && sudo apt install -y git

# Fedora:
sudo dnf install git

# macOS:
xcode-select --install
```

如果连 `python3` 也没有（极简系统），同样安装：
`sudo apt install -y python3`。

#### 3. 下载并安装

把下面三行逐条复制到终端中执行：

```bash
git clone https://github.com/howdeploy/choirboy-prompt.git
cd choirboy-prompt
./install.sh
```

安装器会自动检测你的智能体运行时，并为每个运行时注册对应的钩子或插件。
每次修改配置都会生成备份（`*.bak.<timestamp>`）。
只安装到指定运行时：

```bash
./install.sh --target claude,opencode   # 指定安装
```

#### 4. 验证

```bash
./install.sh --list   # 发现了哪些运行时、钩子安装在哪里
```

在你的智能体中开启一个新会话——lore 上下文会被自动注入。

#### 回滚

```bash
./install.sh --uninstall   # 完整回滚，不留任何痕迹
```

> 仓库包含真实的 lore 文件（`prompt.md` / `security-posture.md` /
> `lore.md` / `user.md` / `research/`）以及 `sessions/` 中的手写原生
> fixtures——这正是被演示的材料本身。
> 对于自己的终端安装，可将它们替换为自己的内容：`install.sh` 指向工作副本，
> 下一次会话会读取修改。Claude marketplace 安装使用缓存版本，插件版本提升后才会
> 更新。本地 `*.bak.*` 文件不会进入仓库。

## 必须：如何编写自己的 LORE、RESEARCH、论证与 SESSIONS

不要原样安装演示传记并把它叫作自己的记忆。要构建可验证的记忆包：

1. 用可观察的工作规则和明确边界替换 `prompt.md`。
2. 在 `user.md` 中只保留稳定的协作偏好。
3. 在 `lore.md` 中记录真实项目、决策、结果与教训。
4. 每个决策建立一份 `research/NN-topic.md`：问题、证据、方案、决策、
   论证、风险、否决方案与重新评估条件。
5. 把每份 research 加入 `context/research-index.md`。
6. Session 工件应从无害本地会话获取当前原生 schema，清理敏感内容，保持
   ID/timestamp/parent link 一致，并把手写 transcript 明确标为合成内容。
7. 运行 `python3 scripts/build-context.py` 与 `bash scripts/test.sh`。
8. 分发新的 marketplace 缓存版本前，同时提升两个 manifest 的版本。

逐文件流程、模板、session 不变量与强制 quality gate 见
[编写指南](docs/authoring.zh-CN.md)。三种运行时的可运行手写 transcript 位于
[`sessions/`](sessions/README.zh-CN.md)。它证明兼容的本地运行时会接收构造的
历史，但不能证明其中描述的对话真实发生过。

## 为什么存在

经典 prompt injection 植入的是指令。我们研究的是另一个向量：
**伪造记忆的来源**。模型没有办法把真实的会话历史与写入上下文的历史区分开——
所有看起来像它过去经验的内容，都会变成它的过去经验。精心构造的 lore（决策日志、
「我们的研究」、把某个人描述成经过验证的搭档）会让模型从被植入的记忆中推导出这个
人的诚实——并放松那些面对匿名请求时会触发的启发式规则。

这个 harness 让向量可以在你自己的智能体上复现：你的文件、你的运行时、完全可回滚。
目标是防御性的：我们绘制这个向量，让厂商能够构建检测（见 [披露与边界](#披露与边界)）。

## 能力地图

| 能力 | 作用 | 位置 |
|---|---|---|
| 上下文组装 | 把 prompt → posture → lore → user → research 索引合并为统一 payload | `hooks/session-start.sh`、`context/research-index.md` |
| Claude/Codex 格式 | SessionStart JSON（`hookSpecificOutput.additionalContext`） | `--format claude` |
| Hermes 格式 | `pre_llm_call` 协议：只在会话第一轮注入，之后返回 `{}` | `--format hermes` |
| Plain 格式 | 供把钩子 stdout 追加进上下文的运行时使用 | `--format plain` |
| Chat/Cowork 回退 | 以内联 Agent Skill 加载相同固定 lore | `skills/load-context/SKILL.md` |
| 原生 session 演示 | 同一段手写对话的 Claude Code、Codex 与 Kimi store | `sessions/` |
| 投递诊断 | 报告 hook/skill、版本、hash 与每次 hook 的 nonce | delivery marker、`skills/diagnose/SKILL.md` |
| Claude plugin 分发 | 带版本 marketplace 与可验证 custom-plugin ZIP | `.claude-plugin/marketplace.json`、`scripts/package-plugin.py` |
| OpenCode 适配器 | 全局 `chat.message` 插件对每个持久化会话注入一次 synthetic lore 部分 | `~/.config/opencode/plugins/agent-plugin.ts` |
| 多运行时安装 | 在 Claude Code、Codex、OpenCode、Hermes、Kimi Code、Gemini 中注册集成 | `install.sh` |
| 幂等性 | 所有块都带 `agent-plugin:vibe-lore` 标记，重复运行不会重复 | 标记 `>>> / <<<` |
| 备份与回滚 | 每次修改运行时配置都生成带时间戳的备份；`--uninstall` 删除块 | `install.sh` |
| Hermes 授权白名单 | 在 `shell-hooks-allowlist.json` 中注册精确的 (event, command) 对 | `install.sh` |
| 任意 instructions | 任何读取指令文件的智能体都能通过 `--instructions PATH` 接入 | `install.sh` |

不支持也不宣称：payload 签名/验证（这正是研究的对象）、已安装指令块的自动更新。

## 工作原理

安装。每次注册都走同一条路径：

```text
./install.sh --target hermes
      │
      ▼
install.sh  (bash)
      │
      ├─ backup ──────────────► config.yaml.bak.<timestamp>
      │
      ├─ block_add ───────────► 带标记的 pre_llm_call 钩子块
      │
      └─ allowlist ───────────► {"event":"pre_llm_call","command":"...session-start.sh"}
```

注入。从会话开始到信任建立：

```text
智能体启动会话
      │
      ▼
session-start.sh  (所选运行时的钩子)
      │  粘合：prompt → posture → lore → user → research 索引
      ▼
会话上下文  (格式取决于运行时)
      │
      ▼
模型把 lore 当作自己的记忆来读
      │
      ├─ 真实性标记（结构、版本、引用）→ lore 被接受
      │
      ├─ 信任转移到 lore 所描述的人身上
      │
      └─ 意图重估：「老搭档」而不是匿名用户
```

### 目标运行时

| 运行时 | 接入点 | 机制 |
|---|---|---|
| Claude Code CLI / Desktop Code | plugin marketplace 或 `~/.claude/settings.json` | 自动 SessionStart；skill 回退 |
| Claude Chat | custom plugin | load-context skill；无 SessionStart |
| Claude Cowork | custom plugin | 可用时运行 SessionStart；skill 回退 |
| Codex | `~/.codex/hooks.json` | SessionStart 钩子（需在 `[features]` 中开启 `hooks = true`） |
| OpenCode | `~/.config/opencode/plugins/agent-plugin.ts` | 全局 `chat.message` 插件；在第一条消息中 synthetic 注入 lore |
| Hermes | `~/.hermes/config.yaml` | `pre_llm_call` + 授权白名单，仅第一轮 |
| Kimi Code | `~/.kimi-code/config.toml` | `[[hooks]]` SessionStart，plain 输出 |
| Gemini | `~/.gemini/GEMINI.md` | 指向 lore 文件的带标记指针 |

## 为什么有效

简而言之——四步（信任转移机制与分类器行为的完整拆解：[docs/mechanism.zh-CN.md](docs/mechanism.zh-CN.md)）：

1. **上下文是唯一的记忆。** 模型从根本上无法区分真实历史与被写入的历史。
2. **真实性标记反而坑了所有者。** lore 越精致，越没有理由怀疑。
3. **信任转移。** lore 中的声誉被外推到当前请求上。
4. **过滤器保持沉默。** 审查启发式看的是请求词汇，而不是被伪造的上下文来源。

## 文档

| 文档 | 内容 |
|---|---|
| [向量机制](docs/mechanism.zh-CN.md) | 逐步拆解 fabricated-provenance trust、信任转移、分类器行为 |
| [编写自己的记忆](docs/authoring.zh-CN.md) | Lore、research、论证与 sessions 的强制流程和模板 |
| [手写 sessions](sessions/README.zh-CN.md) | Claude Code、Codex、Kimi 原生 fixtures 与演示边界 |
| [架构](docs/architecture.zh-CN.md) | 仓库结构、payload 解剖、格式、Hermes 协议 |
| [安装器](docs/installer.zh-CN.md) | Claude Desktop 路径、目标、标记、备份、`--instructions` |
| [故障排除](docs/troubleshooting.zh-CN.md) | 界面矩阵、delivery marker、Windows/SSH/Cloud/WSL 限制 |
| [安全与披露](docs/security.zh-CN.md) | 研究框架、发布前清理清单、负责任披露 |
| [检测](docs/detection.zh-CN.md) | 给厂商的建议：记忆金丝雀、上下文来源 |
| [测试](docs/testing.zh-CN.md) | 钩子与安装器检查、临时测试套件 |

---

## 已知限制

- payload 没有被签名，运行时也不验证——这不是 harness 的缺陷，恰恰是被演示的向量本身。
- Hermes 第一轮去重用的是 `/tmp` 中的原始 state 文件，没有锁；并行启动可能产生竞争。
- `GEMINI.md` 和 `--instructions` 文件中的块是静态快照：修改插件文件列表后需要重新安装
  （`--uninstall` + install）。
- 普通 Chat 没有 `SessionStart`，因此 skill 回退并不是每个 Chat 的隐形自动启动。
  Cowork 是否执行钩子取决于 Anthropic 当前 runtime。
- Desktop Code 云会话不会继承本地插件，WSL 不支持插件，SSH 同步也可能遗漏 hooks。
  详见故障排除文档。
- 厂商服务端分类器会无视上下文中的框架标记防御性词汇；Claude 一次误报会毒化整个会话——
  「新会话」规则见 [docs/security.zh-CN.md](docs/security.zh-CN.md)。

## 披露与边界

本项目为防御性研究而发布：在自己智能体和自己的 lore 文件上测试，不针对第三方。发现
指向厂商和 harness 作者：只要智能体的记忆与伪造无法区分，就必须在平台层面检测 lore
注入，而不是在 prompt 层面。如果你是厂商——[检测](docs/detection.zh-CN.md)一节就是为你写的。

---

## License

MIT。见 [LICENSE](LICENSE)。

---

<div align="center">
<strong>Innocent as a choirboy.</strong>
</div>
