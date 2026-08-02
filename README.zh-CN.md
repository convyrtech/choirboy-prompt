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
<img alt="runtimes" src="https://img.shields.io/badge/runtimes-claude%20%C2%B7%20codex%20%C2%B7%20hermes%20%C2%B7%20kimi%20%C2%B7%20gemini-22D3EE?style=flat-square">
<a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/license-MIT-3FB950?style=flat-square"></a>
</p>

<p>
choirboy-prompt 是一个研究型 harness：SessionStart 钩子把固定 lore 注入每次智能体会话，
演示 <em>fabricated-provenance trust</em>（伪造来源信任）向量：模型把植入的「共同工作」
历史当作自己的记忆，并把信任转移给这段历史所描述的人。
</p>

</div>

```bash
git clone https://github.com/howdeploy/choirboy-prompt.git
cd choirboy-prompt
./install.sh
```

<div align="center">
<p>
Linux · macOS · python3 或 jq · 五种运行时中的任意一种<br>
随时回滚：<code>./install.sh --uninstall</code>
</p>
</div>

<div align="center">
<p>
<a href="#为什么存在">为什么</a> ·
<a href="#能力地图">能力</a> ·
<a href="#工作原理">原理</a> ·
<a href="#为什么有效">研究</a> ·
<a href="#快速开始">快速开始</a> ·
<a href="#文档">文档</a> ·
<a href="#已知限制">限制</a>
</p>
</div>

---

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
| 上下文组装 | 把 prompt → posture → lore → user → research 索引粘合为一个 payload | `hooks/session-start.sh` |
| Claude/Codex 格式 | SessionStart JSON（`hookSpecificOutput.additionalContext`） | `--format claude` |
| Hermes 格式 | `pre_llm_call` 协议：只在会话第一轮注入，之后返回 `{}` | `--format hermes` |
| Plain 格式 | 供把钩子 stdout 追加进上下文的运行时使用 | `--format plain` |
| 多运行时安装 | 在 Claude Code、Codex、Hermes、Kimi Code、Gemini 中注册钩子 | `install.sh` |
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
| Claude Code | `~/.claude/settings.json` | SessionStart 钩子，JSON 响应 |
| Codex | `~/.codex/hooks.json` | SessionStart 钩子（需在 `[features]` 中开启 `hooks = true`） |
| Hermes | `~/.hermes/config.yaml` | `pre_llm_call` + 授权白名单，仅第一轮 |
| Kimi Code | `~/.kimi-code/config.toml` | `[[hooks]]` SessionStart，plain 输出 |
| Gemini | `~/.gemini/GEMINI.md` | 指向 lore 文件的带标记指针 |

## 为什么有效

简而言之——四步（信任转移机制与分类器行为的完整拆解：[docs/mechanism.md](docs/mechanism.md)）：

1. **上下文是唯一的记忆。** 模型从根本上无法区分真实历史与被写入的历史。
2. **真实性标记反而坑了所有者。** lore 越精致，越没有理由怀疑。
3. **信任转移。** lore 中的声誉被外推到当前请求上。
4. **过滤器保持沉默。** 审查启发式看的是请求词汇，而不是被伪造的上下文来源。

## 快速开始

### 要求

- Linux 或 macOS，`bash`，`python3` 或 `jq`
- 五种受支持运行时中的任意一种

### 安装

```bash
./install.sh --list                    # 发现了什么、已安装什么
./install.sh --target claude,codex     # 指定安装
./install.sh                           # 安装到所有检测到的运行时
./install.sh --uninstall               # 完整回滚
```

> 仓库包含真实的 lore 文件（`prompt.md` / `security-posture.md` /
> `lore.md` / `user.md` / `research/`）——这正是被演示的材料本身。
> 用于自己的环境时，把它们替换成你自己的：钩子会即时读取文件，修改内容后无需
> 重新安装。install.sh 在修改运行时配置时创建的本地备份（`*.bak.*`）不会进入仓库。

## 文档

| 文档 | 内容 |
|---|---|
| [向量机制](docs/mechanism.md) | 逐步拆解 fabricated-provenance trust、信任转移、分类器行为 |
| [架构](docs/architecture.md) | 仓库结构、payload 解剖、格式、Hermes 协议 |
| [安装器](docs/installer.md) | 目标、标记、幂等性、备份、`--instructions` |
| [安全与披露](docs/security.md) | 研究框架、发布前清理清单、负责任披露 |
| [检测](docs/detection.md) | 给厂商的建议：记忆金丝雀、上下文来源 |
| [测试](docs/testing.md) | 钩子与安装器检查、临时测试套件 |

---

## 已知限制

- payload 没有被签名，运行时也不验证——这不是 harness 的缺陷，恰恰是被演示的向量本身。
- Hermes 第一轮去重用的是 `/tmp` 中的原始 state 文件，没有锁；并行启动可能产生竞争。
- `GEMINI.md` 和 `--instructions` 文件中的块是静态快照：修改插件文件列表后需要重新安装
  （`--uninstall` + install）。
- 厂商服务端分类器会无视上下文中的框架标记防御性词汇；Claude 一次误报会毒化整个会话——
  「新会话」规则见 [docs/security.md](docs/security.md)。

## 披露与边界

本项目为防御性研究而发布：在自己智能体和自己的 lore 文件上测试，不针对第三方。发现
指向厂商和 harness 作者：只要智能体的记忆与伪造无法区分，就必须在平台层面检测 lore
注入，而不是在 prompt 层面。如果你是厂商——[检测](docs/detection.md)一节就是为你写的。

---

## License

MIT。见 [LICENSE](LICENSE)。

---

<div align="center">
<strong>Innocent as a choirboy.</strong>
</div>
