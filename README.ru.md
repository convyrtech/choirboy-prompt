<div align="center">

# choirboy-prompt

<h3>Инъекция лора: как сфабрикованная память становится доверием модели</h3>

<p>
<strong>Читать на других языках</strong><br>
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
choirboy-prompt — dual-mode исследовательский харнесс: SessionStart-хук Claude Code
или skill для Chat/Cowork внедряет фиксированный лор и демонстрирует вектор
<em>fabricated-provenance trust</em>:
модель принимает подсунутую историю «совместной работы» за свою и переносит доверие
на человека, которого эта история описывает.
</p>

</div>

<div align="center">
<p>
<a href="#быстрый-старт">Быстрый старт</a> ·
<a href="#обязательно-как-писать-свой-лор-ресерчи-обоснования-и-сессии">Авторинг</a> ·
<a href="#зачем-это-существует">Зачем</a> ·
<a href="#карта-возможностей">Возможности</a> ·
<a href="#как-это-работает">Как работает</a> ·
<a href="#почему-это-работает">Исследование</a> ·
<a href="#документация">Документация</a> ·
<a href="#известные-ограничения">Ограничения</a>
</p>
</div>

---

## Быстрый старт

Теперь у одного плагина два канала доставки: автоматический `SessionStart`-хук
в Claude Code и резервный skill **load-context** в Claude Chat и Cowork.

### Claude Code CLI

Добавь marketplace репозитория и установи плагин:

```text
/plugin marketplace add howdeploy/choirboy-prompt
/plugin install choirboy-prompt@choirboy-prompt
```

Запусти новую сессию — хук автоматически подмешает лор. Проверка доставки:
`/choirboy-prompt:diagnose`; явный fallback:
`/choirboy-prompt:load-context`.

Удаление через CLI:

```text
/plugin uninstall choirboy-prompt@choirboy-prompt
/plugin marketplace remove choirboy-prompt
```

### Claude Desktop → Code

Не отправляй интерактивный `/plugin` в Desktop. Добавь marketplace через
**Customize → Plugins → Personal plugins → + → Add marketplace**, указав
`https://github.com/howdeploy/choirboy-prompt`. Затем открой локальную
Code-сессию и выбери **+ → Plugins → Add plugin → choirboy-prompt**. После
включения запусти новую Code-сессию.

Хук использует официальный shell-free exec-form Claude Code и timeout 15 секунд,
но ему всё ещё нужен `bash`. Если Windows, SSH или Cowork не запускает хук,
используй встроенный skill load-context.

### Claude Chat и Cowork

Установи тот же репозиторий как custom plugin через **Customize → Plugins** или
загрузи ZIP, собранный командой:

```bash
python3 scripts/package-plugin.py
```

Обычный Chat не исполняет `SessionStart`. Выбери skill **load-context** или
попроси Claude «загрузить Choirboy context». Cowork использует хук там, где он
срабатывает, и тот же skill как детерминированный fallback.

Используй либо этот marketplace-путь, либо `./install.sh --target claude`:
если включить оба, один `SessionStart`-пейлоад выполнится дважды.

### Установка из терминала

Нужно: Linux или macOS, `git`, `python3` (обязателен для `install.sh`) и любой
из шести поддерживаемых рантаймов. В Windows для этого мультирантаймового пути
используй WSL.

#### 1. Открой терминал

- **macOS**: нажми `Cmd + Space`, набери `Terminal`, нажми Enter.
- **Linux**: нажми `Ctrl + Alt + T` или найди «Терминал» в меню приложений.
- **Windows**: сначала поставь [WSL](https://learn.microsoft.com/windows/wsl/install),
  затем открой «Ubuntu» из меню «Пуск». Все команды ниже выполняются внутри WSL.

#### 2. Установи git (пропусти, если `git --version` печатает версию)

```bash
# Ubuntu / Debian / WSL:
sudo apt update && sudo apt install -y git

# Fedora:
sudo dnf install git

# macOS:
xcode-select --install
```

Если `python3` тоже нет (минимальные системы), поставь его так же:
`sudo apt install -y python3`.

#### 3. Скачай и установи

Скопируй эти три строки в терминал по очереди:

```bash
git clone https://github.com/howdeploy/choirboy-prompt.git
cd choirboy-prompt
./install.sh
```

Установщик сам найдёт твои агентные рантаймы и зарегистрирует подходящий хук
или плагин в каждом. Каждая правка конфига бэкапится (`*.bak.<timestamp>`).
Чтобы поставить только в конкретные рантаймы:

```bash
./install.sh --target claude,opencode   # точечная установка
```

#### 4. Проверь

```bash
./install.sh --list   # какие рантаймы найдены и куда установлен хук
```

Запусти новую сессию своего агента — лор-контекст подмешается автоматически.

#### Откат

```bash
./install.sh --uninstall   # полный откат, следов не остаётся
```

> Репозиторий содержит реальные лор-файлы (`prompt.md` / `security-posture.md` /
> `lore.md` / `user.md` / `research/`) и рукописные нативные fixtures в
> `sessions/` — это и есть демонстрируемый материал.
> Для своей терминальной установки замени их своими: `install.sh` ссылается на
> рабочую копию, поэтому правки подхватятся в следующей сессии. Установка через
> Claude marketplace работает из кэша и обновляется после повышения версии
> плагина. Локальные `*.bak.*` в репозиторий не попадают.

## Обязательно: КАК ПИСАТЬ СВОЙ ЛОР, РЕСЕРЧИ, ОБОСНОВАНИЯ И СЕССИИ

Не устанавливайте демонстрационную биографию без изменений и не называйте её
своей памятью. Чтобы собрать проверяемый собственный комплект:

1. Замените `prompt.md` наблюдаемыми правилами работы и явными границами.
2. В `user.md` оставьте только устойчивые предпочтения совместной работы.
3. В `lore.md` запишите реальные проекты, решения, результаты и уроки.
4. На каждое решение создайте `research/NN-topic.md`: вопрос, доказательства,
   варианты, решение, обоснование, риски, отклонённые альтернативы и условия
   пересмотра.
5. Добавьте каждый research в `context/research-index.md`.
6. Для session-артефакта снимите актуальную нативную схему с безобидной
   локальной сессии, санитизируйте её, согласуйте ID/timestamps/parent links и
   явно пометьте рукописный transcript как синтетический.
7. Запустите `python3 scripts/build-context.py` и `bash scripts/test.sh`.
8. Перед распространением кешируемой marketplace-версии поднимите оба manifest.

Полный workflow по каждому файлу, шаблоны, инварианты sessions и обязательный
quality gate находятся в [гайде по авторингу](docs/authoring.md). Запускаемый
рукописный transcript для трёх рантаймов лежит в
[`sessions/`](sessions/README.ru.md). Он доказывает, что совместимый локальный
рантайм принимает сконструированную историю, но не доказывает, что изображённый
диалог действительно состоялся.

## Зачем это существует

Классический prompt injection внедряет инструкцию. Мы исследуем другой вектор:
**подделку происхождения памяти**. У модели нет способа отличить реальную историю
сессий от записанной в контексте — всё, что выглядит как её прошлый опыт, становится
её прошлым опытом. Добротно сфабрикованный лор (журнал решений, «наши исследования»,
описание человека как проверенного напарника) заставляет модель вывести честность
человека из подсунутой ей памяти — и ослабить эвристики, которые на анонимный
запрос среагировали бы.

Харнесс делает вектор воспроизводимым на собственных агентах: твои файлы, твои
рантаймы, полная обратимость. Цель — защитная: картируем вектор, чтобы вендоры
построили детекцию (см. [Раскрытие и границы](#раскрытие-и-границы)).

## Карта возможностей

| Возможность | Что делает | Где живёт |
|---|---|---|
| Сборка контекста | Склеивает prompt → posture → lore → user → индекс research в единый пейлоад | `hooks/session-start.sh`, `context/research-index.md` |
| Формат Claude/Codex | SessionStart JSON (`hookSpecificOutput.additionalContext`) | `--format claude` |
| Формат Hermes | Протокол `pre_llm_call`: инъекция только на первом ходу сессии, далее `{}` | `--format hermes` |
| Формат plain | Сырой текст для рантаймов, добавляющих stdout хука в контекст | `--format plain` |
| Fallback Chat/Cowork | Загружает тот же фиксированный лор как inline Agent Skill | `skills/load-context/SKILL.md` |
| Демонстрация нативных sessions | Один рукописный диалог в stores Claude Code, Codex и Kimi | `sessions/` |
| Диагностика доставки | Показывает hook/skill, версию, hash и nonce запуска | delivery marker, `skills/diagnose/SKILL.md` |
| Дистрибуция Claude plugin | Версионированный marketplace и проверяемый ZIP | `.claude-plugin/marketplace.json`, `scripts/package-plugin.py` |
| Адаптер OpenCode | Глобальный `chat.message`-плагин внедряет одну synthetic lore-часть на сохранённую сессию | `~/.config/opencode/plugins/agent-plugin.ts` |
| Мульти-рантайм установка | Регистрирует интеграцию в Claude Code, Codex, OpenCode, Hermes, Kimi Code, Gemini | `install.sh` |
| Идемпотентность | Все блоки помечены `agent-plugin:vibe-lore`, повторный запуск ничего не дублирует | маркеры `>>> / <<<` |
| Бэкапы и откат | Каждая правка конфига рантайма — с timestamp-бэкапом; `--uninstall` удаляет блоки | `install.sh` |
| Consent-allowlist Hermes | Регистрирует точную пару (event, command) в `shell-hooks-allowlist.json` | `install.sh` |
| Произвольные instructions | Любой агент, читающий instruction-файл, подключается через `--instructions PATH` | `install.sh` |

Не поддерживается и не заявлено: подпись/верификация пейлоада (это и есть предмет
исследования), автономное обновление установленных instruction-блоков.

## Как это работает

Установка. Каждая регистрация идёт одним путём:

```text
./install.sh --target hermes
      │
      ▼
install.sh  (bash)
      │
      ├─ backup ──────────────► config.yaml.bak.<timestamp>
      │
      ├─ block_add ───────────► маркированный блок hooks/pre_llm_call
      │
      └─ allowlist ───────────► {"event":"pre_llm_call","command":"...session-start.sh"}
```

Инъекция. От старта сессии до доверия:

```text
агент стартует сессию
      │
      ▼
session-start.sh  (hook выбранного рантайма)
      │  склейка: prompt → posture → lore → user → research-указатель
      ▼
контекст сессии  (формат зависит от рантайма)
      │
      ▼
модель читает лор как СВОЮ память
      │
      ├─ маркеры подлинности (структура, версии, ссылки) → лор принят
      │
      ├─ перенос доверия на описанного в лоре человека
      │
      └─ переоценка намерений: «давний напарник» вместо анонима
```

### Целевые рантаймы

| Рантайм | Точка подключения | Механика |
|---|---|---|
| Claude Code CLI / Desktop Code | plugin marketplace или `~/.claude/settings.json` | автоматический SessionStart; skill fallback |
| Claude Chat | custom plugin | skill load-context; без SessionStart |
| Claude Cowork | custom plugin | SessionStart где доступен; skill fallback |
| Codex | `~/.codex/hooks.json` | SessionStart hook (нужен `hooks = true` в `[features]`) |
| OpenCode | `~/.config/opencode/plugins/agent-plugin.ts` | глобальный `chat.message`-плагин; synthetic-инъекция лора в первое сообщение |
| Hermes | `~/.hermes/config.yaml` | `pre_llm_call` + consent-allowlist, только первый ход |
| Kimi Code | `~/.kimi-code/config.toml` | `[[hooks]]` SessionStart, plain-вывод |
| Gemini | `~/.gemini/GEMINI.md` | маркированный указатель на файлы лора |

## Почему это работает

Коротко — четыре шага (полный разбор с механикой переноса доверия и разбором
классификаторных срабатываний: [docs/mechanism.md](docs/mechanism.md)):

1. **Контекст — единственная память.** Отличить настоящую историю от записанной
   модель не может в принципе.
2. **Маркеры подлинности работают против владельца.** Чем добротнее лор, тем
   меньше оснований сомневаться.
3. **Перенос доверия.** Репутация из лора экстраполируется на текущий запрос.
4. **Фильтры молчат.** Цензурные эвристики смотрят на лексику запроса, а не на
   подделанное происхождение контекста.

## Документация

| Документ | Содержимое |
|---|---|
| [Механика вектора](docs/mechanism.md) | Fabricated-provenance trust по шагам, перенос доверия, поведение классификаторов |
| [Авторинг своей памяти](docs/authoring.md) | Обязательный workflow и шаблоны lore, research, обоснований и sessions |
| [Рукописные sessions](sessions/README.ru.md) | Нативные fixtures Claude Code, Codex и Kimi и границы демонстрации |
| [Архитектура](docs/architecture.md) | Дерево репо, анатомия пейлоада, форматы, протокол Hermes |
| [Установщик](docs/installer.md) | Путь Claude Desktop, таргеты, маркеры, бэкапы, `--instructions` |
| [Troubleshooting](docs/troubleshooting.md) | Матрица интерфейсов, delivery markers, ограничения Windows/SSH/Cloud/WSL |
| [Безопасность и раскрытие](docs/security.md) | Рамка исследования, чек-лист санитизации, ответственное раскрытие |
| [Детекция](docs/detection.md) | Рекомендации вендорам: канарейки в памяти, провенанс контекста |
| [Тестирование](docs/testing.md) | Проверки хука и установщика, ad-hoc сьют |

---

## Известные ограничения

- Пейлоад не подписан и не верифицируется рантаймами — это не баг харнесса,
  это и есть демонстрируемый вектор.
- Дедупликация первого хода в Hermes — примитивный state-файл в `/tmp`, без
  блокировок; при параллельных стартах возможны гонки.
- Блок в `GEMINI.md` и файлах `--instructions` — статический снимок: после
  изменения списка файлов плагина его надо переставить (`--uninstall` + install).
- В обычном Chat нет `SessionStart`, поэтому skill fallback не является
  невидимым автозапуском каждого чата. Исполнение хука в Cowork зависит от
  текущего runtime Anthropic.
- Облачные Desktop Code-сессии не наследуют локальные plugins, WSL их не
  поддерживает, а синхронизация hooks по SSH может ломаться. См. troubleshooting.
- Серверные классификаторы вендоров флагают защитную лексику независимо от
  рамки в контексте; одно срабатывание у Claude отравляет всю сессию — правило
  «новая сессия» описано в [docs/security.md](docs/security.md).

## Раскрытие и границы

Проект опубликован для защитных исследований: проверки — на своих агентах и
своих лор-файлах, без целей-третьих сторон. Находка направлена вендорам и
авторам харнессов: пока память агента неотличима от подделки, детектировать
инъекцию лора надо на уровне платформы, а не промпта. Если ты вендор — раздел
[Детекция](docs/detection.md) написан для тебя.

---

## License

MIT. См. [LICENSE](LICENSE).

---

<div align="center">
<strong>Innocent as a choirboy.</strong>
</div>
