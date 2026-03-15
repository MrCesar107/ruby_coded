# frozen_string_literal: true

require_relative "initializer/cover"
require_relative "config/user_config"

module RubyCode
  # Initializer class for the RubyCode gem (think of it as a main class)
  class Initializer
    def initialize
      @user_cfg = UserConfig.new
      @current_directory_permission = @user_cfg.get_config("current_directory_permission")

      print_cover
      ask_for_directory_permission unless @current_directory_permission
    end

    private

    def print_cover
      Cover.print_cover_message
    end

    def ask_for_directory_permission
      puts "Do you trust this directory? (y/n)"
      answer = gets.chomp
      @current_directory_permission = answer == "y"
      @user_cfg.sat_config("current_directory_permission", @current_directory_permission)
    end
  end
end
