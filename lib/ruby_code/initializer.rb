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

      print_cover
      ask_for_directory_permission unless @current_directory_permission
      check_authentication
    end

    private

    def print_cover
      Cover.print_cover_message
    end

    def ask_for_directory_permission
      @current_directory_permission = @prompt.yes?("Do you trust this directory?")
      @user_cfg.sat_config("current_directory_permission", @current_directory_permission)
    end

    def check_authentication
      nil if @user_cfg.get_config("provider")

      provider = @prompt.select("You must login to an AI provider. Please select one of the following:",
                                Auth::AuthManager.new.configured_providers,
                                per_page: 10)
      puts "Logging in to #{provider}..."
      # Auth::AuthManager.new.login(provider)
    end
  end
end
