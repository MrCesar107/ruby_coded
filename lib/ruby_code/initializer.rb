# frozen_string_literal: true

require "ruby_llm"
require "tty-prompt"

require_relative "initializer/cover"
require_relative "config/user_config"
require_relative "auth/auth_manager"
require_relative "chat/app"

module RubyCode
  # Initializer class for the RubyCode gem (think of it as a main class)
  class Initializer
    def initialize
      @user_cfg = UserConfig.new
      @prompt = TTY::Prompt.new
      @auth_manager = Auth::AuthManager.new

      ask_for_directory_permission unless @user_cfg.directory_trusted?
      @auth_manager.check_authentication
      @auth_manager.configure_ruby_llm!
      start_chat
    end

    private

    def ask_for_directory_permission
      if @prompt.yes?("Do you trust this directory? (#{Dir.pwd})")
        @user_cfg.trust_directory!
      else
        exit 0
      end
    end

    def start_chat
      Chat::App.new(model: resolved_chat_model, user_config: @user_cfg).run
    end

    def resolved_chat_model
      stored = @user_cfg.get_config("model")
      return stored.to_s if stored && !stored.to_s.strip.empty?

      RubyLLM.config.default_model
    end
  end
end
