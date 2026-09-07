# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "benchmark", "~> 0.5"
gem "rake"
gem "rlsl", "~> 1.0"
gem "rubocop", "~> 1.88"
gem "test-unit"
gem "simplecov", require: false

install_if -> { RUBY_PLATFORM.match?(/darwin/) } do
  gem "metaco"
end
