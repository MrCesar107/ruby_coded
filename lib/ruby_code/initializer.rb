# frozen_string_literal: true

require_relative "initializer/cover"

module RubyCode
  # Initializer class for the RubyCode gem (think of it as a main class)
  class Initializer
    $directory_permission ||= false

    def initialize
      print_cover
      ask_for_directory_permission unless $directory_permission
    end

    private

    def print_cover
      Cover.print_cover_message
    end

    def ask_for_directory_permission
      puts "Do you trust this directory? (y/n)"
      answer = gets.chomp
      $directory_permission = answer == "y"
    end
  end
end
