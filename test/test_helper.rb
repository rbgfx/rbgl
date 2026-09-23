# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter %r{/test/}
  minimum_coverage 90
end

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "test-unit"
require "rbgl"
require "rlsl"
