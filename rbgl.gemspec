# frozen_string_literal: true

require_relative "lib/rbgl/version"

Gem::Specification.new do |spec|
  spec.name = "rbgl"
  spec.version = RBGL::VERSION
  spec.authors = ["Yudai Takada"]
  spec.email = ["t.yudai92@gmail.com"]

  spec.summary = "RuBy Graphics Library - Pure Ruby software rendering with cross-platform GUI"
  spec.description = "A pure Ruby graphics library with software rendering engine and cross-platform GUI support (X11, Wayland, Cocoa)."
  spec.homepage = "https://github.com/ydah/rbgl"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.require_paths = ["lib"]

  spec.add_dependency "larb", "~> 1.0"
  spec.add_development_dependency "benchmark", "~> 0.5"
  spec.add_development_dependency "rlsl", "~> 0.1"
  spec.add_development_dependency "rubocop", "~> 1.88"

  spec.bindir = "exe"
  spec.executables = ["rbgl"]
end
