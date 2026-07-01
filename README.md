# RubyCoded

```
         /\
        /  \
       /    \         ____        _              ____          _
      /------\       |  _ \ _   _| |__  _   _   / ___|___   __| | ___   __| |
     /  \  /  \      | |_) | | | | '_ \| | | | | |   / _ \ / _` |/ _ \ / _` |
    /    \/    \     |  _ <| |_| | |_) | |_| | | |__| (_) | (_| |  __/ (_| |
    \    /\    /     |_| \_\\__,_|_.__/ \__, |  \____\___/ \__,_|\___| \__,_|
     \  /  \  /                         |___/
      \/    \/
       \    /
        \  /
         \/
```

An AI-powered terminal coding assistant built in Ruby. Chat with LLMs, let an agent edit your project files, or plan tasks — all from your terminal.

## Features

- **Chat mode** — Talk to an LLM directly in a full terminal UI (TUI) built with [ratatui](https://github.com/nicholasgasior/ratatui-ruby)
- **Agent mode** — The model can read, write, edit, and delete files in your project, create directories, and run shell commands with user confirmation
- **Plan mode** — Generate structured plans before implementing, with interactive clarification questions and auto-switch to agent mode when ready
- **ChatGPT Plus/Pro support** — Use your ChatGPT subscription to access GPT-5.x models via the Codex backend — no API credits required
- **Multi-provider support** — Works with OpenAI and Anthropic out of the box (OAuth and API key authentication)
- **In-session login** — Authenticate or switch providers at any time with `/login`, no restart needed
- **Tool confirmation** — Write and dangerous operations require explicit approval; safe operations (read, list) run automatically
- **Token & cost tracking** — Live status bar showing token usage, estimated session cost, and auth mode indicator
- **Plugin system** — Extend the chat with custom state, input handlers, renderer overlays, and commands
- **Slash commands** — `/agent`, `/plan`, `/model`, `/login`, `/history`, `/tokens`, `/commands reload`, `/commands list`, `/skills reload`, `/skills list`, `/help`, and more

## Requirements

- Ruby >= 3.3.0
- An OpenAI or Anthropic account (ChatGPT Plus/Pro subscription, or API key)

## Installation

```bash
gem install ruby_coded
```

## Usage

Navigate to any project directory and run:

```bash
ruby_coded
```

On first launch you'll be asked to authenticate with a provider. After that, you're dropped into chat mode.

### Modes

| Command | Description |
|---|---|
| `/agent on` | Enable agent mode (file tools + shell access) |
| `/agent off` | Disable agent mode |
| `/plan on` | Enable plan mode (read-only tools, structured planning) |
| `/plan off` | Disable plan mode |
| `/plan save` | Save the current plan to a file |
| `/model` | Switch to a different model |
| `/login` | Authenticate with a provider (OpenAI, Anthropic) |
| `/commands reload` | Reload custom markdown commands from the current project |
| `/commands list` | List currently loaded custom markdown commands |
| `/skills reload` | Reload project-local skills from the current project |
| `/skills list` | List currently loaded project-local skills |
| `/tokens` | Show detailed token usage breakdown |
| `/history` | Show conversation history |
| `/clear` | Clear the conversation |
| `/help` | Show all available commands |

### Agent mode

When agent mode is active, the model has access to these tools:

| Tool | Risk level | Description |
|---|---|---|
| `read_file` | Safe | Read file contents |
| `list_directory` | Safe | List directory contents |
| `write_file` | Confirm | Write a new file |
| `edit_file` | Confirm | Search and replace in a file |
| `create_directory` | Confirm | Create a new directory |
| `delete_path` | Dangerous | Delete a file or directory |
| `run_command` | Dangerous | Execute a shell command |
| `git_status` | Safe | Show repository status |
| `git_diff` | Safe | Show staged or unstaged diff |
| `git_add` | Confirm | Stage files or all changes |
| `git_commit` | Confirm | Create a local git commit with a message |

Safe tools run without asking. Confirm and dangerous tools show the operation details and wait for your approval (`y` to approve, `n` to reject, `a` to approve all remaining).

### Plan mode

Plan mode restricts the model to read-only tools and a planning-oriented system prompt. The model will analyze your project and propose a structured plan. If the model needs clarification, it presents interactive options you can select or answer with custom text.

### Custom commands

You can define your own project-specific slash commands using Markdown files inside:

```bash
.ruby_coded/commands/
```

Each `.md` file represents one custom command. RubyCoded loads these commands into:

- the slash-command autocomplete list
- `/help`
- command execution

#### File format

Use YAML frontmatter followed by the command body:

```md
---
command: /review-auth
description: Review auth implementation
usage: /review-auth [file]
---

Review the authentication implementation and suggest improvements.
Focus on risks, bugs, and refactoring opportunities.
```

#### Required fields

- `command` — command name, must start with `/`
- `description` — short description shown in autocomplete and help

#### Optional fields

- `usage` — custom usage text shown in `/help`

#### How it works

The Markdown body is used as the prompt template for the command. For example:

```bash
/review-auth lib/ruby_coded/chat/command_handler.rb
```

RubyCoded will send the command body to the model and append the extra user input as additional context.

#### Managing commands

Custom commands are loaded from the current project. After adding, editing, or deleting command files, you can manage them without restarting the app.

Reload command definitions:

```bash
/commands reload
```

The reload command reports:

- how many custom commands were added
- how many were removed
- how many are currently available
- how many invalid files were ignored
- how many conflicting commands were ignored
- invalid file names
- conflicting command names

List currently loaded custom commands:

```bash
/commands list
```

#### Notes

- Core commands take precedence over custom commands.
- Plugin commands also take precedence over custom Markdown commands.
- Invalid Markdown command files are ignored during reload.

### Project skills

RubyCoded also supports project-local skills: reusable Markdown instructions that are automatically injected into chat, plan, and agent behavior when they match the active mode.

Skills are loaded from:

```bash
.rubycoded/skills/
```

This path is intentionally different from custom commands, which use:

```bash
.ruby_coded/commands/
```

Each `.md` file defines one skill.

#### Skill file format

Use YAML frontmatter followed by the skill body:

```md
---
name: Rails Migration Safety
description: Improve safety when changing schema or migrations
modes:
  - agent
  - plan
tags:
  - rails
  - migration
trigger: schema
priority: 10
---

Before proposing or applying migration changes:
- inspect existing schema and recent migrations
- prefer additive, reversible changes
- call out data backfill or locking risks explicitly
```

#### Required fields

- `name` — unique skill name within the project
- `description` — short explanation shown in `/skills list`
- `modes` — one or more supported modes: `chat`, `plan`, `agent`

#### Optional fields

- `tags` — keywords used for simple relevance matching
- `trigger` — plain-text trigger checked against the current request
- `priority` — higher-priority skills are listed first and applied first

#### How skills are activated

Current behavior is intentionally simple:

- all skills compatible with the active mode are loaded
- if a request matches skill `tags` or `trigger`, matching skills are preferred
- if nothing matches, all mode-compatible skills remain available

This means skills are useful immediately without requiring manual activation UI.

#### Managing skills

Reload skills after adding, editing, or deleting skill files:

```bash
/skills reload
```

List the currently loaded skills:

```bash
/skills list
```

The reload command reports:

- how many skills were added
- how many were removed
- how many are currently available
- how many invalid files were ignored
- how many duplicate skill names were ignored

#### Skill behavior notes

- Skills are project-local and loaded relative to the current project root.
- Skills are injected into system instructions for `chat`, `plan`, and `agent` modes.
- If a skill conflicts with higher-priority system instructions or the user’s explicit request, the higher-priority instruction should win.
- Invalid or malformed skill files are ignored during reload.
- If duplicate skill names exist, the first loaded definition wins and later duplicates are ignored.

## Keyboard shortcuts

| Key | Action |
|---|---|
| `Enter` | Send message |
| `Esc` | Cancel streaming / clear input |
| `Ctrl+C` | Quit |
| `Up/Down` | Scroll chat history |
| `Left/Right` | Move cursor in input |
| `Home/End` | Jump to start/end of input |
| `Tab` | Autocomplete commands |

## Development

```bash
git clone https://github.com/MrCesar107/ruby_code.git
cd ruby_code
bundle install
bundle exec rake test
```

To run the application locally:

```bash
bundle exec exe/ruby_coded
```

## What's next

- Display context window size (depending on the model)
- UI element to indicate the AI is performing a task
- Improve custom commands further (validation, conflict reporting, management UX)
- Skills implementation
- Implement Google Auth for Gemini
- Local LLM support
- Session recovery system by ID
- Context summarization when approaching the model's context limit

## Contributing

Contributions are welcome! To get started:

1. Fork the repository
2. Create a new branch for your feature or fix (`git checkout -b my-feature`)
3. Make your changes and add tests if applicable
4. Make sure all tests pass (`bundle exec rake test`)
5. Commit your changes (`git commit -m "Add my feature"`)
6. Push to your fork (`git push origin my-feature`)
7. Open a Pull Request against the `main` branch of this repository

Your PR will be reviewed and merged if everything looks good. If you're unsure about a change, feel free to open an issue first to discuss it.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
