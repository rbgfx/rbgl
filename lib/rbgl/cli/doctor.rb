# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

module RBGL
  module CLI
    class Doctor
      class << self
        def default_checks
          {
            file_backend: ->(doctor, env, platform) { doctor.__send__(:check_file_backend, env, platform) },
            wayland: ->(doctor, env, platform) { doctor.__send__(:check_wayland, env, platform) },
            x11: ->(doctor, env, platform) { doctor.__send__(:check_x11, env, platform) },
            cocoa: ->(doctor, env, platform) { doctor.__send__(:check_cocoa, env, platform) },
            rlsl: ->(doctor, env, platform) { doctor.__send__(:check_rlsl, env, platform) }
          }
        end
      end

      def initialize(json: false, io: $stdout, env: ENV, platform: RUBY_PLATFORM, ruby_version: RUBY_VERSION, checks: {})
        @json = json
        @io = io
        @env = env
        @platform = platform
        @ruby_version = ruby_version
        @checks = self.class.default_checks.merge(checks)
      end

      def run
        report = collect

        if @json
          output_json(report)
        else
          output_text(report)
        end

        0
      end

      def collect
        {
          rbgl_version: RBGL::VERSION,
          ruby_version: @ruby_version,
          platform: @platform,
          file_backend: collect_component(:file_backend),
          wayland: collect_component(:wayland),
          x11: collect_component(:x11),
          cocoa: collect_component(:cocoa),
          rlsl: collect_component(:rlsl)
        }
      end

      private

      def collect_component(key)
        @checks.fetch(key).call(self, @env, @platform)
      rescue StandardError => e
        { available: false, error: "#{e.class}: #{e.message}" }
      end

      def output_text(report)
        @io.puts("RBGL version: #{report[:rbgl_version]}")
        @io.puts("Ruby version: #{report[:ruby_version]}")
        @io.puts("RUBY_PLATFORM: #{report[:platform]}")
        @io.puts
        dump_section("File backend", report[:file_backend])
        dump_section("Wayland", report[:wayland])
        dump_section("X11", report[:x11])
        dump_section("Cocoa", report[:cocoa])
        dump_section("RLSL", report[:rlsl])
      end

      def output_json(report)
        @io.puts(JSON.pretty_generate(report))
      end

      def dump_section(name, values)
        @io.puts("#{name}:")
        values.each do |key, value|
          @io.puts("  #{key}: #{format_value(value)}")
        end
        @io.puts
      end

      def format_value(value)
        return value.is_a?(TrueClass) || value.is_a?(FalseClass) ? (value ? "yes" : "no") : value.inspect
      end

      def check_file_backend(_env, _platform)
        output_dir = Dir.mktmpdir("rbgl-doctor")
        backend = RBGL::GUI::FileBackend.new(1, 1, "rbgl-doctor", output_dir: output_dir)
        backend.present(RBGL::Engine::Framebuffer.new(1, 1))

        { available: true, output_dir: output_dir }
      ensure
        backend&.close
        FileUtils.rm_rf(output_dir) if output_dir
      end

      def check_wayland(env, _platform)
        require_ok, require_error = safe_require("rbgl/gui/wayland/connection")
        {
          display_env: env["WAYLAND_DISPLAY"],
          display_available: !env["WAYLAND_DISPLAY"].nil?,
          require_ok: require_ok,
          require_error: require_error
        }
      end

      def check_x11(env, _platform)
        require_ok, require_error = safe_require("rbgl/gui/x11/connection")
        {
          display_env: env["DISPLAY"],
          display_available: !env["DISPLAY"].nil?,
          require_ok: require_ok,
          require_error: require_error
        }
      end

      def check_cocoa(_env, platform)
        darwin = platform.include?("darwin")
        return { platform: platform, supported: false } unless darwin

        require_ok, require_error = safe_require("metaco")
        {
          platform: platform,
          supported: true,
          require_ok: require_ok,
          require_error: require_error
        }
      end

      def check_rlsl(_env, _platform)
        begin
          require "rlsl"
          version = Gem.loaded_specs["rlsl"]&.version&.to_s

          { require_ok: true, version: version }
        rescue LoadError => e
          { require_ok: false, error: "#{e.class}: #{e.message}" }
        end
      end

      def safe_require(file)
        require file
        [true, nil]
      rescue LoadError => e
        [false, "#{e.class}: #{e.message}"]
      end
    end
  end
end
