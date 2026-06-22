# frozen_string_literal: true

require "test_helper"

class Bundler::VivariumTest < Test::Unit::TestCase
  test "VERSION" do
    assert do
      ::Bundler::Vivarium.const_defined?(:VERSION)
    end
  end
end
