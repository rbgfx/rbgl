# frozen_string_literal: true

source "https://rubygems.org"

gemspec

gem "rake"
gem "test-unit"
gem "simplecov", require: false
gem "rlsl", github: "ydah/rlsl", branch: "main"

install_if -> { RUBY_PLATFORM.match?(/darwin/) } do
  gem "metaco"
end
