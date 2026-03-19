# frozen_string_literal: true

require "tty-prompt"

require_relative "initializer/cover"
require_relative "config/user_config"
require_relative "auth/auth_manager"

module RubyCode
  # Initializer class for the RubyCode gem (think of it as a main class)
  class Initializer
    def initialize
      @user_cfg = UserConfig.new
      @prompt = TTY::Prompt.new
      @current_directory_permission = @user_cfg.get_config("current_directory_permission")
      @auth_manager = Auth::AuthManager.new

      print_cover
      ask_for_directory_permission unless @current_directory_permission
      @auth_manager.check_authentication
      @auth_manager.configure_ruby_llm!
    end

    private

    def print_cover
      Cover.print_cover_message
    end

    def ask_for_directory_permission
      @current_directory_permission = @prompt.yes?("Do you trust this directory?")
      @user_cfg.set_config("current_directory_permission", @current_directory_permission)
    end
  end
end
