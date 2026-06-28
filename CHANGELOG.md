## [Unreleased]

- **Create a git integration tool**: Create a git tool for git workflows in projects
- **Enable Agent mode by default**: Enable the agent mode by default when a session starts

## [0.3.0] - 2026-04-24

### Added

- **Pro-only Codex model handling**: `gpt-5.3-codex-spark` and `gpt-5.2-codex` are tagged as `pro_only` in the Codex model catalog and render with a `(Pro only)` marker in the `/model` selector. Plus/free JWT plan claims now hide Pro-only models from the selector, while unknown plans keep the previous behavior to avoid breaking Pro users.
- **Automatic Codex model fallback**: When the Codex backend rejects a model with `not supported when using Codex with a ChatGPT account`, the request is transparently retried against `gpt-5.4` and the user is informed via a system message.
- **Provider metadata in `/model`**: `CodexModel` now exposes provider metadata so the selector shows `(openai)` instead of `(unknown)`.
- **Unified command catalog**: New `RubyCoded::Commands` module with a central `Catalog`, `CommandDefinition`, and provider abstraction (`CoreProvider`, `PluginProvider`, `MarkdownProvider`) consolidating all slash commands in a single source of truth, replacing the hand-rolled `help.txt` and ad-hoc registrations.
- **Markdown custom commands**: Users can now drop `*.md` files under `~/.ruby_coded/commands/` (or the project-local `.ruby_coded/commands/`) to define reusable slash commands with front-matter metadata, loaded via the new `MarkdownLoader` / `MarkdownProvider`.
- **Context window tracking**: New `State::ContextWindow` module plus status bar integration that shows live context usage per model, driven by per-turn token tracking.

### Changed

- **Status bar polish**: The status bar now renders context window usage alongside the model/auth indicators and hides noisy fields when data is unavailable.
- **Command handler refactor**: `CommandHandler` is now powered by the unified catalog (core + plugin + markdown providers) and delegates custom command execution to the new `CustomCommands` mixin.

### Fixed

- **Context window indicator for ChatGPT Plus/Pro users**: `CodexBridge` now parses the `response.completed` SSE event and feeds `input`/`output`/`reasoning`/`cached` token usage into `State`, mirroring the API path. `session_context_tokens_used` reflects the last turn's live prompt size via the new `State#last_turn_context_tokens` helper, eliminating the double-counting that happened because both bridges re-send the full history on each request.

## [0.2.2] - 2026-04-17

### Fixed

- **OAuth credentials lost after in-TUI login**: When logging in to OpenAI via OAuth from within the chat (`/login`) while already authenticated with another provider (e.g. Anthropic) and using a non-Codex model, the freshly stored OAuth credentials were wiped from `~/.ruby_coded/config.yaml`. The root cause was two `UserConfig` instances holding independent in-memory copies of the config; when `ensure_valid_codex_model!` called `@user_config.set_config("model", "gpt-5.4")`, the stale hash (loaded before the OAuth login) was serialized back to disk, overwriting the OAuth credentials written moments earlier by `CredentialsStore`. Fixed by threading a single shared `UserConfig` through `Initializer`, `AuthManager`, `CredentialsStore` and `Chat::App`.

## [0.2.1] - 2026-04-17

### Fixed

- **Startup crash when stored model provider is not authenticated**: The CLI no longer raises `RubyLLM::ConfigurationError` at startup when the model saved in `~/.ruby_coded/config.yaml` belongs to a provider that has no credentials on the current machine (e.g. switching computers with only Anthropic authenticated but a GPT model stored). Instead, the app falls back to the default model of the authenticated provider and shows an in-chat system message suggesting `/login` or `/model` to adjust.

### Added

- `AuthManager#provider_for_model` and `AuthManager#model_provider_authenticated?` helpers to detect the provider of a given model name and validate that its credentials are available.

## [0.2.0] - 2026-04-16

### Added

- **ChatGPT Plus/Pro OAuth authentication**: Use your ChatGPT subscription to access GPT-5.x models via the Codex backend — no API credits required
- **`/login` command**: Authenticate with providers (OpenAI, Anthropic) directly from the TUI without restarting
- **In-TUI login wizard**: Native multi-step login flow with OAuth and API key support, replacing the old TUI-suspend approach
- **CodexBridge**: Dedicated HTTP client for the ChatGPT Codex Responses API with SSE streaming, stateless conversation history, tool calls, and automatic token refresh
- **Codex model catalog**: Local catalog of ChatGPT-available models (gpt-5.4, gpt-5.2, gpt-5.2-codex, etc.) integrated with the `/model` selector
- **Status bar indicator**: Shows `(ChatGPT)` or `(API)` next to the model name to distinguish authentication mode
- **JWT decoder**: Extracts `chatgpt_account_id` from OAuth tokens for Codex API authentication

### Changed

- OpenAI OAuth now authenticates via ChatGPT Codex backend instead of the OpenAI Platform API
- OAuth scopes expanded to `openid profile email offline_access` with Codex-specific auth params
- AuthManager skips OpenAI OAuth credentials for RubyLLM configuration (handled by CodexBridge)
- Default OpenAI model updated to `gpt-5.4`

## [0.1.1] - 2026-04-15

- Fix CI workflow

## [0.1.0] - 2026-04-15

- Initial release
