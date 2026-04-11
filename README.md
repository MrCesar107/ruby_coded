# RubyCode

```
         /\
        /  \
       /    \         ____        _              ____          _
      /------\       |  _ \ _   _| |__  _   _   / ___|___   __| | ___
     /  \  /  \      | |_) | | | | '_ \| | | | | |   / _ \ / _` |/ _ \
    /    \/    \     |  _ <| |_| | |_) | |_| | | |__| (_) | (_| |  __/
    \    /\    /     |_| \_\\__,_|_.__/ \__, |  \____\___/ \__,_|\___|
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
- **Multi-provider support** — Works with OpenAI and Anthropic out of the box (OAuth and API key authentication)
- **Tool confirmation** — Write and dangerous operations require explicit approval; safe operations (read, list) run automatically
- **Token & cost tracking** — Live status bar showing token usage and estimated session cost
- **Plugin system** — Extend the chat with custom state, input handlers, renderer overlays, and commands
- **Slash commands** — `/agent`, `/plan`, `/model`, `/history`, `/tokens`, `/help`, and more

## Requirements

- Ruby >= 3.3.0
- An OpenAI or Anthropic account (API key or OAuth)

## Installation

```bash
gem install ruby_code
```

## Usage

Navigate to any project directory and run:

```bash
ruby_code
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

Safe tools run without asking. Confirm and dangerous tools show the operation details and wait for your approval (`y` to approve, `n` to reject, `a` to approve all remaining).

### Plan mode

Plan mode restricts the model to read-only tools and a planning-oriented system prompt. The model will analyze your project and propose a structured plan. If the model needs clarification, it presents interactive options you can select or answer with custom text.

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
bundle exec exe/ruby_code
```

## What's next

- Find a way to update the autocomplete plugin when a new command is added []
- Display context window size (depending on the model) []
- UI element to indicate the AI is performing a task []
- Add the possibility to create custom commands []
- Skills implementation []
- Implement Google Auth for Gemini []
- Session recovery system by ID []

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
