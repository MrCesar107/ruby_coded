# frozen_string_literal: true

require_relative "lib/ruby_code/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_code"
  spec.version = RubyCode::VERSION
  spec.authors = ["Cesar Rodriguez"]
  spec.email = ["cesar.rodriguez.lara54@gmail.com"]

  spec.summary = "AI-powered terminal coding assistant with agent mode, plan mode, and multi-provider LLM support."
  spec.description = "RubyCode is a terminal-based AI coding assistant built in Ruby. " \
                     "It provides a full TUI chat interface with support for multiple LLM providers " \
                     "(OpenAI, Anthropic, etc.), an agent mode with filesystem tools for reading, writing, " \
                     "and editing project files, a plan mode for structured task planning, " \
                     "and a plugin system for extensibility."
  spec.homepage = "https://github.com/MrCesar107/ruby_code"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/MrCesar107/ruby_code"
  spec.metadata["changelog_uri"] = "https://github.com/MrCesar107/ruby_code/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/ .rubocop.yml])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  spec.add_dependency "ratatui_ruby", "~> 1.4"
  spec.add_dependency "ruby_llm", "~> 1.13.2"
  spec.add_dependency "tty-prompt"
  spec.add_dependency "unicode-display_width"
  spec.add_dependency "webrick"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
