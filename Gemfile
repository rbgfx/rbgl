# frozen_string_literal: true

source "https://rubygems.org"

# Isolated dependency updaters do not have sibling checkouts.
gemspec

gem "larb", path: "../larb" if File.directory?(File.expand_path("../larb", __dir__))
gem "rlsl", path: "../rlsl" if File.directory?(File.expand_path("../rlsl", __dir__))
gem "tessel", path: "../tessel" if File.directory?(File.expand_path("../tessel", __dir__))
if RUBY_PLATFORM.include?("darwin") && File.directory?(File.expand_path("../metaco", __dir__))
  gem "metaco", path: "../metaco"
end

gem "benchmark", "~> 0.5"
gem "rake"
gem "rake-compiler", "~> 1.2"
gem "rubocop", "~> 1.88"
gem "test-unit"
gem "simplecov", require: false
