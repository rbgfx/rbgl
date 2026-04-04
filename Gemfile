# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake"
gem "test-unit"
gem "simplecov", require: false

install_if -> { RUBY_PLATFORM.match?(/darwin/) } do
  gem "metaco"
end
