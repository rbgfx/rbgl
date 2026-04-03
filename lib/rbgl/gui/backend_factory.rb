# frozen_string_literal: true

module RBGL
  module GUI
    class BackendFactory
      class << self
        def build(backend, width:, height:, title:, **options)
          case backend
          when :auto, :native
            build(native_backend_key, width: width, height: height, title: title, **options)
          when :file
            FileBackend.new(width, height, title, **options)
          when :x11
            require_relative "x11/backend"
            X11::Backend.new(width, height, title)
          when :wayland
            require_relative "wayland/backend"
            Wayland::Backend.new(width, height, title)
          when :cocoa
            require_relative "cocoa/backend"
            Cocoa::Backend.new(width, height, title)
          when Backend
            backend
          else
            raise "Unknown backend: #{backend}"
          end
        end

        private

        def native_backend_key(platform: RUBY_PLATFORM, env: ENV)
          case platform
          when /darwin/
            :cocoa
          when /linux/
            return :wayland if env["WAYLAND_DISPLAY"]
            return :x11 if env["DISPLAY"]

            raise "No display server found (DISPLAY or WAYLAND_DISPLAY not set)"
          else
            raise "Unsupported platform: #{platform}"
          end
        end
      end
    end
  end
end
