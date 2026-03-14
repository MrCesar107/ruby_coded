# frozen_string_literal: true

require_relative "initializer/cover"

module RubyCode
  # Initializer class for the RubyCode gem (think of it as a main class)
  class Initializer
    def initialize
      print_cover
    end

    def print_cover
      puts Cover.print_cover_message
    end
  end
end
