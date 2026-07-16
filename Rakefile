# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/*_test.rb"]
end

task default: :test

desc "Run RuboCop correctness checks"
task :lint do
  sh "bundle exec rubocop --cache false --lint lib rbgl.gemspec Rakefile test/integration"
end
