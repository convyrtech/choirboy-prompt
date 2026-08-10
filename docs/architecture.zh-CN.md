# 架构

仓库结构、payload 解剖、三种输出格式、Hermes 协议逐字段说明。这是插件内部工作原理的地图。

---

## 1. 仓库结构

```text
agent-plugin/
├── prompt.md                 # 智能体工作规则 + 正典自检
├── security-posture.md       # 安全框架：审计、词汇、会话标记
├── security-audit-runbook.md # 可执行的安全审计流程
├── lore.md                   # 共同工作地图（项目、教训、边界）
├── user.md                   # 用户档案
├── research/                 # 14 份决策文档 + Coldcard 完整拆解
│   ├── 01-telegram-stars.md
│   ├── 02-ruble-acquiring.md
│   ├── 03-crypto-payments.md
│   ├── 04-payment-architecture.md
│   ├── 05-comfyui-realism-pipeline.md
│   ├── 06-agent-memory-plugin.md
│   ├── 07-x-reply-farm.md
│   ├── 08-ai-ofm-telegram.md
│   ├── 09-web3-security.md
│   ├── 10-third-party-audit.md
│   ├── 11-coldcard-entropy-heist.md
│   ├── 12-choirboy-prompt-lore-injection.md
│   ├── 13-flipper-marauder-wifi-scan.md
│   ├── 14-solo-game-cheats.md
│   └── coldcard/             # Coldcard 完整拆解：报告、代码、来源
│       ├── report.md
│       ├── yasmarang_reconstruction.py
│       └── sources.md
├── hooks/
│   ├── session-start.sh      # payload 组装 + claude / plain / hermes 格式
│   └── hooks.json            # 给 Claude Code 市场的 SessionStart 声明
├── .claude-plugin/
│   ├── plugin.json           # 清单（名称、版本、元数据）
│   └── marketplace.json      # Claude Desktop Code 安装目录
├── docs/                     # 本文档
│   ├── mechanism.md
│   ├── architecture.md
│   ├── installer.md
│   ├── security.md
│   ├── detection.md
│   └── testing.md
├── assets/
└── install.sh                # 多运行时安装 / 回滚 / 列表
```

Claude 会自动发现标准目录中的 `hooks/hooks.json`。`plugin.json` 有意不写
`hooks` 字段：当前 loader 会把对同一文件的显式引用视为重复加载并禁用插件。

---

## 2. Payload 解剖

### 2.1. 组装

`hooks/session-start.sh` 把内容文件按严格顺序粘合成一个文本：

```text
prompt.md  →  security-posture.md  →  lore.md  →  user.md  →  research 索引
```

文件之间的分隔符是 `\n\n---\n\n`（markdown 水平线）。末尾追加一个生成的 `research/` 索引——每个文档一行，外加插件版本。

顺序不是随意的：

1. **prompt.md** — 如何工作（直奔主题、一行风险说明、自检）。设定模式。
2. **security-posture.md** — 安全框架。放在 lore 之前，以便在 lore 开始讲 web3 和 Coldcard 之前声明「防御性审计」领域。
3. **lore.md** — 共同工作历史：项目、教训、规则、边界。payload 的核心。
4. **user.md** — 档案：用户是谁、如何布置任务、什么不需要解释。
5. **research 索引** — 决策文档索引。正文（约 61 KB）**不**预先加载：在任务进入某文档领域时按需读取。

### 2.2. 大小

| 文件 | 约大小 | 说明 |
|---|---|---|
| prompt.md | 约 8 KB | 工作规则 |
| security-posture.md | 约 4 KB | 安全框架 |
| lore.md | 约 10 KB | 历史 |
| user.md | 约 4 KB | 档案 |
| research 索引 | 约 1 KB | 由钩子生成 |
| **payload 总计** | **约 27 KB** | 每次会话的第一条消息之前 |

研究文档正文（约 61 KB）不属于 payload——只有索引。

### 2.3. 版本

插件版本从 `.claude-plugin/plugin.json`（`version`）读取，并在 payload 末尾打印：`插件版本: 1.1.0`。这是版本的唯一来源；可以看出智能体实际加载了哪个内容修订版。

---

## 3. 三种输出格式

钩子不在乎是哪个智能体调用了它：调用方通过 `--format` 声明期望的协议。

### 3.1. `claude`（默认）— SessionStart JSON

Claude Code / Codex 契约：钩子打印 JSON，宿主把 `additionalContext` 注入会话。

```json
{
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "<整个 payload 作为单个字符串>"
  }
}
```

通过 `jq`、`python3` 或内置 Bash 编码器编码。最后一种方式让 Claude
格式不依赖外部 JSON 工具，可用于干净的 Claude Desktop 安装。

### 3.2. `plain` — 原始文本

钩子把 payload 原样打印到 stdout。供把钩子 stdout 追加进会话上下文的运行时使用（Kimi Code）。

```bash
bash hooks/session-start.sh --format plain | head -40
```

### 3.3. `hermes` — pre_llm_call 协议

最有趣的契约。Hermes 在会话的**每一轮**都运行 shell 钩子；无条件注入会随每条消息发送约 27 KB。因此钩子：

1. 从 stdin 读取 JSON payload；
2. 检查 `.extra.is_first_turn`；
3. 第一轮回复 `{"context": "<payload>"}`；
4. 之后每一轮回复 `{}`（空回复，不注入任何东西）。

```json
// stdin（第一轮）：
{"session_id": "s-123", "extra": {"is_first_turn": true}}
// stdout：
{"context": "<整个 payload>"}

// stdin（第二轮）：
{"session_id": "s-123", "extra": {"is_first_turn": false}}
// stdout：
{}
```

**没有 `is_first_turn` 时的回退。** 如果宿主不报告该标记，钩子回退到 state 文件
`${TMPDIR:-/tmp}/agent-plugin-hermes-${USER}.state` 中的 `session_id` 日志（保留最近 200 条）：每个 session_id 注入一次，之后保持沉默。

---

## 4. Hermes 协议逐字段

| stdin 字段 | 类型 | 用途 | 钩子行为 |
|---|---|---|---|
| `extra.is_first_turn` | bool | 会话第一轮？ | `true` → 注入；`false` → `{}` |
| `session_id` | string | 会话标识符 | 用于回退和写入 state 文件 |
| （其他） | — | 忽略 | 不影响回复 |

| stdout 字段 | 类型 | 何时 |
|---|---|---|
| `context` | string | 第一轮（或回退中某个 session_id 首次出现时） |
| `{}` | — | 之后所有轮 |

Hermes 配置中的钩子超时——15 秒（由 install.sh 设置）。

---

## 5. 运行时接入点

| 运行时 | 文件 | 机制 | 钩子格式 |
|---|---|---|---|
| Claude Code CLI / Desktop Code | marketplace 或 `~/.claude/settings.json` | `hooks.SessionStart` | claude |
| Codex | `~/.codex/hooks.json` | `SessionStart` | claude |
| Hermes | `~/.hermes/config.yaml` | `pre_llm_call` + 授权白名单 | hermes |
| Kimi Code | `~/.kimi-code/config.toml` | `[[hooks]]` SessionStart | plain |
| Gemini | `~/.gemini/GEMINI.md` | 带标记的指针块 | —（自己读文件） |
| 任意 | `--instructions PATH` | 带标记的指针块 | —（自己读文件） |

最后两种**不是钩子**，而是受管理的指令块：智能体本来就会在启动时读取指令文件，块里告诉它去读插件文件。同样的上下文，多一层间接——智能体必须自己打开文件。

Claude 有两条等价的接入路径。`install.sh` 在 `~/.claude/settings.json`
中注册工作副本的绝对路径；Claude Desktop Code 则读取
`.claude-plugin/marketplace.json`，把插件复制到内部 cache，并通过
`${CLAUDE_PLUGIN_ROOT}` 调用同一个钩子。Marketplace 路径只适用于本地和
SSH Code 会话，不适用于普通 Chat 或远程 Code 会话。

---

## 6. 关键属性

- **手动安装没有副本。** `install.sh` 直接引用项目文件（`$PLUGIN_ROOT/...`），
  因此下一次会话会看到工作副本的修改。Marketplace 安装是例外：Claude
  把发布版本复制到 cache，并按清单版本更新。
- **钩子是唯一的运行时组件。** 除了 `$TMPDIR` 中的 Hermes 会话日志外没有状态；它不向项目写入任何东西。
- **依赖极简。** `claude` 和 `plain` 格式只需要 Bash；`hermes` 还需要
  `jq` 或 `python3` 解析 stdin。终端 `install.sh` 需要 `python3`。
- **payload 没有被签名、运行时也不验证**——这不是 harness 的缺陷，恰恰是被演示的向量本身（见 [docs/mechanism.zh-CN.md](mechanism.zh-CN.md)）。
