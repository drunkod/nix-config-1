# AI Tools Architecture

## Overview

The `ai-tools/` directory contains shared AI assistant configuration rendered
for multiple tools (Claude Code, GitHub Copilot, Gemini CLI, OpenCode, Codex).
Content is defined once and rendered into each tool's native format by the Nix
build system.

## Directory Structure

```text
ai-tools/
├── default.nix          # Entry point — assembles everything for each harness
├── commands.nix         # Renders commands for each tool
├── agents.nix           # Renders agents for each tool
├── base.md              # Shared system prompt (CLAUDE.md)
├── agents/
│   └── general/         # Agent prompt content (.md files)
├── commands/
│   ├── git/             # Git workflow commands
│   ├── project/         # Project management commands
│   └── quality/         # Code quality commands
├── skills/              # Skill directories (loaded on demand)
└── claude-code/
    ├── assets/          # Icons etc.
    ├── hooks/           # Claude Code lifecycle hooks (.nix files)
    └── permissions.nix  # Allow/ask/deny permission profiles
```

## How It Fits Together

```text
ai-tools/default.nix
    ├── agents.nix          reads agents/general/*.md
    ├── commands.nix        reads commands/**/*.nix
    └── claude-code/
            ├── hooks/      lifecycle scripts
            └── permissions.nix

modules/programs/claude-code.nix   (Home Manager module)
    imports claude.nix              base package + env + aliases
    imports ai-tools/default.nix    rendered content
    writes ~/.claude/               active profile
    writes ~/.claude-work/          work profile
    writes ~/.claude-api/           local Ollama profile
```

Each profile directory is a self-contained Claude Code config root selected
via `CLAUDE_CONFIG_DIR`.

---

## Claude Profiles

Three profiles are configured out of the box.

| Alias          | Config dir        | Model          | Use for                        |
|----------------|-------------------|----------------|--------------------------------|
| `claude`       | `~/.claude`       | default        | Personal projects              |
| `claude-work`  | `~/.claude-work`  | default        | Work projects                  |
| `claude-api`   | `~/.claude-api`   | qwen3.5:9b     | Local Ollama (no API key)      |

### Switching Profiles

```bash
# Default profile
claude

# Work profile
claude-work

# Local Ollama profile (no Anthropic API key required)
claude-api
```

All three profiles share:
- The same `base.md` system prompt (`CLAUDE.md`)
- The same skills directory
- The same hooks and permissions

Only `claude-api` differs — it overrides `model`, `ANTHROPIC_BASE_URL`, and
related env vars to point at a local Ollama instance.

### Adding a New Profile

1. Add a `mkClaudeProfile` call in `modules/programs/claude-code.nix`:

```nix
claudeFiles =
  mkClaudeFiles "agents" aiTools.claudeCode.agents
  // mkClaudeFiles "commands" aiTools.claudeCode.commands
  // mkClaudeProfile ".claude" { }
  // mkClaudeProfile ".claude-work" { }
  // mkClaudeProfile ".claude-api" { ... }
  // mkClaudeProfile ".claude-research" {   # ← new
      model = "opus";
    };
```

2. Add a shell alias:

```nix
shellAliases = {
  claude-work     = "CLAUDE_CONFIG_DIR=$HOME/.claude-work claude";
  claude-api      = "CLAUDE_CONFIG_DIR=$HOME/.claude-api claude";
  claude-research = "CLAUDE_CONFIG_DIR=$HOME/.claude-research claude"; # ← new
};
```

3. Rebuild: `sudo darwin-rebuild switch --flake .#m1-min`

---

## Skills

Skills are Markdown files (or directories of them) that Claude Code loads on
demand using the `/skill` slash command. They provide durable, reusable
workflows without polluting the main system prompt.

### Structure

Each skill is a directory under `ai-tools/skills/`:

```text
ai-tools/skills/
├── git-toolkit/
│   └── index.md        # or any .md files
├── github-toolkit/
│   └── index.md
└── my-skill/
    └── index.md
```

All skill directories are symlinked into every profile's `skills/` folder at
build time by `mkClaudeProfile`.

### Using a Skill

Inside a Claude Code session:

```
/skill git-toolkit
/skill github-toolkit
```

This loads the skill's content into the current context on demand.

### Adding a Skill

1. Create a directory under `ai-tools/skills/`:

```bash
mkdir -p ai-tools/skills/my-skill
```

2. Write the skill content:

```bash
cat > ai-tools/skills/my-skill/index.md << 'EOF'
# My Skill

Describe what this skill does and when to invoke it.

## Usage

Step-by-step workflow or reference content.
EOF
```

3. Rebuild to symlink it into all profiles:

```bash
sudo darwin-rebuild switch --flake .#m1-min
```

4. Use it in Claude Code:

```
/skill my-skill
```

No changes to any `.nix` file are required — `default.nix` picks up all
directories under `ai-tools/skills/` automatically.

### Excluding a Skill from Specific Tools

Some skills are excluded from certain harnesses (e.g. `skill-creator` is
excluded from Claude Code and Codex). To exclude a new skill, add it to the
relevant filter in `ai-tools/default.nix`:

```nix
harnessSkillFilters = {
  claudeCode = {
    exclude = [
      "skill-creator"
      "my-skill"    # ← add here to exclude from Claude Code
    ];
  };
};
```

---

## Commands

Commands are slash commands available inside Claude Code sessions. They are
defined as `.nix` files under `ai-tools/commands/` and rendered into
`~/.claude/commands/` at build time.

### Using a Command

```
/commit-changes
/code-review
/deep-check
```

### Adding a Command

1. Create a `.nix` file in the appropriate subdirectory:

```nix
# ai-tools/commands/quality/my-check.nix
let
  commandName = "my-check";
  description = "What this command does";
  allowedTools = "Read, Grep, Bash(make:*)";
  argumentHint = "[path]";
  prompt = ''
    Your command prompt here.
  '';
in
{
  ${commandName} = {
    inherit commandName description allowedTools argumentHint prompt;
  };
}
```

2. Rebuild — `commands.nix` discovers all `.nix` files automatically.

---

## Agents

Agents are persistent sub-agents with scoped tools and models, invoked by
Claude Code for isolated tasks (debugging, refactoring, test running).

### Available Agents

| Agent        | Model  | Purpose                              |
|--------------|--------|--------------------------------------|
| `debugger`   | opus   | Root cause analysis                  |
| `refactorer` | sonnet | Structure improvements               |
| `test-runner`| haiku  | Test execution and failure analysis  |

### Adding an Agent

1. Add the agent content file:

```bash
cat > ai-tools/agents/general/my-agent.md << 'EOF'
You are a specialist in X.

When invoked:
1. ...
2. ...

Report:
- ...
EOF
```

2. Register it in `ai-tools/agents.nix`:

```nix
agents = {
  # ... existing agents ...
  my-agent = {
    name = "my-agent";
    description = "One-line description for the agent picker";
    tools = [ "Read" "Bash" "Grep" ];
    model = {
      claude = "sonnet";
      copilot = "claude-sonnet-4.6";
      gemini = "gemini-3.1-pro-preview";
      opencode = "openai/gpt-5.4";
    };
    permission = {
      edit = "ask";
      bash = "ask";
    };
    content = builtins.readFile (agentsBasePath + "/general/my-agent.md");
  };
};
```

3. Rebuild.
