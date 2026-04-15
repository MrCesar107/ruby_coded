# frozen_string_literal: true

# This module contains the version of the RubyCode gem
module RubyCode
  VERSION = "0.1.1"

  def self.gem_version
    Gem::Version.new(VERSION).freeze
  end
end
