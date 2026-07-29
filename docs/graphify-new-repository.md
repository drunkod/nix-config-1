# Graphify: безопасное подключение нового репозитория

Основной подробный документ находится в корне репозитория:

```text
GRAPHIFY-TUTORIAL.md
```

Этот файл — краткая инструкция для `m1-min` и Claude Code.

Главное правило:

> Один процесс Graphify MCP должен обслуживать один явно выбранный граф одного репозитория.

Граф проекта хранится здесь:

```text
<project>/graphify-out/graph.json
```

Graphify больше не должен автоматически брать сохранённый граф другого проекта
или искать граф в фиксированных fallback-директориях.

---

## 1. Применить конфигурацию `m1-min`

```bash
cd ~/nix-config
nh darwin switch .#m1-min
```

После переключения откройте новый терминал.

Удалите старое глобальное состояние выбора графа:

```bash
graphify-mcp-set-graph --clear
```

Перезапустите программы, которые уже запустили MCP-сервер. Работающий процесс
MCP не меняет граф автоматически.

---

## 2. Подготовить новый проект

```bash
cd /path/to/project
```

Создайте `.graphifyignore`, чтобы offline-индексация содержала только код:

```gitignore
# Docs / prose
*.md
*.mdx
*.rst
*.txt
*.yaml
*.yml
*.pdf
*.doc
*.docx
*.ppt
*.pptx
*.xls
*.xlsx
*.csv

# Images / media
*.png
*.jpg
*.jpeg
*.gif
*.webp
*.svg
*.mp3
*.wav
*.mp4
*.mov

# Generated / dependencies
.graphify-src/
.graphify-runtime/
.venv/
venv/
graphify-out/
result/
node_modules/
dist/
build/
.cache/
coverage/
target/

/docs/
/assets/
/images/
/screenshots/
```

Не используйте схему `*`, `!*/`, `!*.ext`: закреплённая версия Graphify может
обработать такое повторное включение директорий не так, как ожидается.

---

## 3. Создать первый граф

```bash
graphify-extract .
```

Или напрямую через flake:

```bash
nix run ~/nix-config#graphify-extract -- .
```

Для code-only/offline режима хороший итог выглядит так:

```text
found N code, 0 docs, 0 papers, 0 images
```

Проверьте файлы:

```bash
test -s graphify-out/graph.json
test -s graphify-out/manifest.json
```

---

## 4. Обновлять граф после изменений

```bash
graphify-update .
```

`graphify-update` теперь сохраняет существующие `graph.json` и `manifest.json`:
они нужны для incremental update.

Используйте новый `graphify-extract`, если:

- граф отсутствует или повреждён;
- правила `.graphifyignore` сильно изменились;
- содержимое директории было заменено другим проектом.

---

## 5. Запросы без MCP

Для обычных вопросов это самый прозрачный способ:

```bash
graphify-query \
  "what depends on RuntimeBridge" \
  --graph "$PWD/graphify-out/graph.json"
```

Всегда передавайте `--graph` явно.

---

## 6. Безопасные режимы MCP

### Автоматический режим проекта

```bash
graphify-mcp-find-graph
graphify-mcp-auto
```

Порядок выбора:

1. `GRAPHIFY_GRAPH_PATH`;
2. `GRAPHIFY_PROJECT_ROOT`;
3. поиск `graphify-out/graph.json` вверх от текущей рабочей директории;
4. ошибка.

Сохранённый глобальный граф и fallback-репозитории не используются.

Если граф не найден, ошибка является правильным и безопасным результатом.

### Явный граф — рекомендуемый режим

Для GUI-программ и Claude Code:

```bash
graphify-mcp-run /absolute/project/graphify-out/graph.json
```

Можно передать директорию проекта:

```bash
graphify-mcp-run /absolute/project
```

### Явно сохранённый глобальный граф

Используйте только осознанно:

```bash
graphify-mcp-set-graph /absolute/project
graphify-mcp-set-graph --show
graphify-mcp-saved
graphify-mcp-set-graph --clear
```

`graphify-mcp-auto` не читает это состояние.

---

## 7. Claude Code на macOS

Найдите абсолютный путь wrapper-команды:

```bash
command -v graphify-mcp-run
```

В корне проекта создайте `.mcp.json`:

```json
{
  "mcpServers": {
    "graphify": {
      "command": "/Users/test/.nix-profile/bin/graphify-mcp-run",
      "args": [
        "/Users/test/Documents/work/example/graphify-out/graph.json"
      ]
    }
  }
}
```

Замените оба пути реальными абсолютными путями. Не используйте `~` или `$HOME`
в JSON-конфигурации.

Перед запуском:

```bash
cd /Users/test/Documents/work/example
graphify-update .
claude
```

---

## 8. Claude Code sandbox без Nix

Используйте скрипт:

```text
scripts/graphify-sandbox.sh
```

Он создаёт отдельный `uv` runtime и использует ту же закреплённую ревизию
Graphify, что и `flake.lock`.

Требования:

- Bash;
- `uv`;
- Git и сеть, либо смонтированный исходный код Graphify.

Первый граф:

```bash
cd /workspace/project
bash /workspace/nix-config/scripts/graphify-sandbox.sh extract .
```

Обновление:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh update /workspace/project
```

Запрос:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh query \
  "what calls RuntimeBridge" \
  --graph /workspace/project/graphify-out/graph.json
```

MCP:

```bash
bash /workspace/nix-config/scripts/graphify-sandbox.sh mcp \
  /workspace/project/graphify-out/graph.json
```

Для sandbox без сети смонтируйте Graphify source:

```bash
export GRAPHIFY_SOURCE_DIR=/workspace/vendor/graphify
```

Пример `.mcp.json`:

```json
{
  "mcpServers": {
    "graphify": {
      "command": "bash",
      "args": [
        "/workspace/nix-config/scripts/graphify-sandbox.sh",
        "mcp",
        "/workspace/project/graphify-out/graph.json"
      ],
      "env": {
        "GRAPHIFY_SANDBOX_STATE_DIR": "/workspace/.cache/graphify-sandbox"
      }
    }
  }
}
```

Для offline source добавьте в `env`:

```json
"GRAPHIFY_SOURCE_DIR": "/workspace/vendor/graphify"
```

Не копируйте файл сохранённого MCP-графа с macOS в sandbox.

---

## 9. Диагностика

Проверить автоматический выбор:

```bash
graphify-mcp-find-graph
```

Принудительно выбрать граф для одного процесса:

```bash
GRAPHIFY_GRAPH_PATH=/absolute/project/graphify-out/graph.json \
  graphify-mcp-auto
```

Принудительно выбрать корень проекта:

```bash
GRAPHIFY_PROJECT_ROOT=/absolute/project \
  graphify-mcp-auto
```

Если `GRAPHIFY_GRAPH_PATH` или `GRAPHIFY_PROJECT_ROOT` неверен, launcher завершится
с ошибкой и не будет искать другой граф.

Если MCP показывает старые данные:

1. проверьте абсолютный путь в `.mcp.json`;
2. выполните `graphify-update .` в нужном проекте;
3. полностью перезапустите MCP-процесс программы.

---

## 10. Краткий чек-лист

- [ ] один `graphify-out/` на репозиторий или worktree;
- [ ] первый запуск через `graphify-extract`;
- [ ] последующие изменения через `graphify-update`;
- [ ] CLI query всегда получает явный `--graph`;
- [ ] GUI/Claude Code использует `graphify-mcp-run` с абсолютным путём;
- [ ] `graphify-mcp-auto` используется только при надёжном project working directory;
- [ ] saved mode используется только явно;
- [ ] после обновления графа MCP-процесс перезапускается;
- [ ] extraction показывает `0 docs, 0 papers, 0 images`.
