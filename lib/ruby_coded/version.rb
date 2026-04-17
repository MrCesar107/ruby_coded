# frozen_string_literal: true

# This module contains the version of the RubyCoded gem
module RubyCoded
  VERSION = "0.2.1"

  def self.gem_version
    Gem::Version.new(VERSION).freeze
  end
end
