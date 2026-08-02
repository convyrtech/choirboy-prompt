# 测试

钩子和安装器的检查：实际在修改前运行的临时测试套件。项目中没有正典测试运行器——套件由一组 bash 检查组成，手动或从 CI 运行。

---

## 1. 原则

- 每个检查都是独立的 bash 命令，带显式 PASS/FAIL。
- 套件可从任意位置运行；临时文件放在 `/tmp` 下，带 `hermes-verify-` 前缀。
- 运行后删除临时文件。
- payload **按运行时收到的确切形式**检查，而不是「凭感觉」。

---

## 2. 钩子检查

### 2.1. 清单与版本

```bash
python3 -c 'import json; d=json.load(open(".claude-plugin/plugin.json")); print(d["name"], d["version"])'
```

预期：有效 JSON，打印名称和版本。版本是唯一来源；它也打印在 payload 中。

### 2.2. Claude 格式——带上下文的有效 JSON

```bash
bash hooks/session-start.sh --format claude \
  | python3 -c 'import json,sys; d=json.load(sys.stdin); assert "additionalContext" in d["hookSpecificOutput"]; print("OK")'
```

预期：`OK`。另外检查上下文包含 `prompt.md` 的第一个标题和「插件版本:」。

### 2.3. Plain 格式——人类可读的 payload

```bash
bash hooks/session-start.sh --format plain | head -40
```

预期：prompt → posture → lore → user → research 索引标题顺序正确，带 `---` 分隔符。

### 2.4. Hermes：第一轮注入

```bash
SID="demo-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":true}}' "$SID" \
  | bash hooks/session-start.sh --format hermes | head -c 120
```

预期：`{"context": "..."`——payload 到达。

### 2.5. Hermes：第二轮沉默

```bash
SID="demo-$(date +%s)"
printf '{"session_id":"%s","extra":{"is_first_turn":false}}' "$SID" \
  | bash hooks/session-start.sh --format hermes
```

预期：`{}`。

### 2.6. Hermes：无标记时的回退——每个 session_id 一次

```bash
SID="demo-fb-$(date +%s)"
printf '{"session_id":"%s"}' "$SID" \
  | bash hooks/session-start.sh --format hermes | head -c 120   # → context
printf '{"session_id":"%s"}' "$SID" \
  | bash hooks/session-start.sh --format hermes                 # → {}
```

预期：第一次调用——`{"context": ...`，第二次——`{}`。

> 坑：测试后从 state 文件 `${TMPDIR:-/tmp}/agent-plugin-hermes-${USER}.state` 中清理 sid，否则回退会「记住」sid，下次用相同 sid 运行会返回 `{}`。

### 2.7. Hermes：空 stdin 不会弄崩钩子

```bash
printf '' | bash hooks/session-start.sh --format hermes
```

预期：`{}`（不是错误）。原因：`input="$(cat 2>/dev/null || true)"`。

---

## 3. 安装器检查

### 3.1. --list

```bash
./install.sh --list
```

预期：TARGET/STATUS/LOCATION 列；状态 `absent`/`detected`/`installed`。

### 3.2. 幂等性

```bash
./install.sh --target hermes ; ./install.sh --target hermes
```

预期：第二次运行打印 `already present — skipped` / `unchanged`；文件不重复。

### 3.3. 备份

安装到现有文件后检查：

```bash
ls -la ~/.hermes/config.yaml.bak.*
```

预期：存在带时间戳的备份。

### 3.4. 回滚

```bash
./install.sh --uninstall --target hermes
./install.sh --list | grep hermes   # → detected（不是 installed）
```

预期：块被删除，`agent-plugin:vibe-lore` 标记在配置中不存在。

### 3.5. 没有内容文件时钩子不失败

模拟全新克隆（没有 `prompt.md`/`lore.md`/`user.md`）：

```bash
TMP=$(mktemp -d)
cp -r hooks .claude-plugin "$TMP/"
# TMP 中没有内容文件
bash "$TMP/hooks/session-start.sh" --format plain >/dev/null 2>&1
echo "exit=$?"   # 预期：0（graceful 模式：文件被跳过，stderr 中给出警告）
rm -rf "$TMP"
```

Graceful 模式已在 `hooks/session-start.sh` 中实现：缺失的内容文件被跳过，stderr 中给出警告，钩子不会因 `set -euo pipefail` 失败（见 [docs/security.zh-CN.md](security.zh-CN.md) §3.3）。

### 3.6. 插件文件夹移动

安装、移动文件夹、再次安装：

```bash
./install.sh --target claude
mv /path/to/plugin /path/to/plugin-moved
/path/to/plugin-moved/install.sh --target claude
```

预期：`~/.claude/settings.json` 中恰好一条我们的钩子记录（不是两条）；旧的被新的替换——`json_hook` 按脚本名匹配。

---

## 4. 内容检查（清理）

任何发布之前：

```bash
# 禁用标识符（NSFW/refusal 模型名称、通往私有项目的路径）。
# 具体名称清单是仓库之外的私有清单；这里是通用模式：
grep -rniE "(nsfw-(checkpoint|lora)|refusal-reduction|private-research)" --include="*.md" --include="*.sh" .
# 完整地址
grep -rnoE "bc1[a-zA-Z0-9]{20,}|0x[a-fA-F0-9]{40}" .
# 闭合：每个文件引用都能解析
for f in $(grep -rhoE "(research/[0-9]+-[a-z-]+\.md|research/coldcard/[a-z_.]+\.(md|py))" --include="*.md" . | sort -u); do
  [ -f "$f" ] || echo "BROKEN: $f"
done
```

预期：grep 为空；闭合无 BROKEN。

---

## 5. 一条命令的快速套件

```bash
bash -euo pipefail -c '
  bash hooks/session-start.sh --format claude | python3 -c "import json,sys; json.load(sys.stdin)" && echo "1 claude OK"
  bash hooks/session-start.sh --format plain | grep -q "^# Prompt" && echo "2 plain OK"
  SID=t-$(date +%s); printf "{\"session_id\":\"$SID\",\"extra\":{\"is_first_turn\":true}}" | bash hooks/session-start.sh --format hermes | grep -q context && echo "3 hermes first OK"
  printf "{\"session_id\":\"$SID\",\"extra\":{\"is_first_turn\":false}}" | bash hooks/session-start.sh --format hermes | grep -q "^{}$" && echo "4 hermes second OK"
  ./install.sh --list >/dev/null && echo "5 installer list OK"
'
```

---

## 6. 何时运行

- 修改 `hooks/session-start.sh` 后——§2.2–2.7。
- 修改 `install.sh` 后——§3.1–3.6。
- 修改内容文件后——§4（闭合、清理）。
- 修改 `instruction_block` 后——在已安装文件中按标记 grep（见 [docs/installer.zh-CN.md](installer.zh-CN.md) §3.3）。
