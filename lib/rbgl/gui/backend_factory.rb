# frozen_string_literal: true

module RBGL
  module GUI
    class BackendFactory
      AUTO_BACKEND_ERRORS = [LoadError, SystemCallError, BackendUnavailable].freeze

      class << self
        def build(backend, width:, height:, title:, platform: RUBY_PLATFORM, env: ENV, **options)
          case backend
          when :auto
            build_auto_backend(
              width: width,
              height: height,
              title: title,
              platform: platform,
              env: env,
              **options
            )
          else
            build_specific_backend(backend, width: width, height: height, title: title, env: env, **options)
          end
        end

        private

        def build_auto_backend(width:, height:, title:, platform:, env:, builder: nil, **options)
          builder ||= method(:build_specific_backend)
          errors = []

          native_backend_candidates(platform: platform, env: env).each do |candidate|
            return builder.call(candidate, width: width, height: height, title: title, env: env, **options)
          rescue *AUTO_BACKEND_ERRORS => error
            errors << [candidate, error]
          end

          raise_auto_backend_error(errors)
        end

        def build_specific_backend(backend, width:, height:, title:, env: ENV, **options)
          case backend
          when :file
            FileBackend.new(width, height, title, **options)
          when :x11
            require_relative "x11/backend"
            X11::Backend.new(width, height, title, env: env)
          when :wayland
            require_relative "wayland/backend"
            Wayland::Backend.new(width, height, title, env: env)
          when :cocoa
            require_relative "cocoa/backend"
            Cocoa::Backend.new(width, height, title, env: env)
          when Backend
            backend
          else
            raise BackendSelectionError, "Unknown backend: #{backend}"
          end
        end

        def raise_auto_backend_error(errors)
          return if errors.empty?

          details = errors.map { |backend, error| "#{backend}: #{error.class}: #{error.message}" }.join(", ")
          raise BackendUnavailable, "Failed to initialize any native backend (#{details})"
        end

        def native_backend_candidates(platform:, env:)
          case platform
          when /darwin/
            [:cocoa]
          when /linux/
            candidates = []
            candidates << :wayland if env["WAYLAND_DISPLAY"]
            candidates << :x11 if env["DISPLAY"]
            return candidates unless candidates.empty?

            raise BackendUnavailable, "No display server found (DISPLAY or WAYLAND_DISPLAY not set)"
          else
            raise BackendUnavailable, "Unsupported platform: #{platform}"
          end
        end
      end
    end
  end
end
