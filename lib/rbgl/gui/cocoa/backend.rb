# frozen_string_literal: true

begin
  require "metaco"
  METACO_AVAILABLE = true
rescue LoadError
  METACO_AVAILABLE = false
end

module RBGL
  module GUI
    module Cocoa
      class Backend < GUI::Backend
        def initialize(width, height, title = "RBGL")
          unless METACO_AVAILABLE
            raise LoadError, "metaco gem is required for Cocoa backend. Install it with: gem install metaco"
          end

          super
          Metaco.init
          @handle = Metaco.window_create(width, height, title)
        end

        def present(framebuffer)
          return unless @handle

          Metaco.set_pixels(@handle, framebuffer.to_rgba_bytes, framebuffer.width, framebuffer.height)
          Metaco.present(@handle)
        end

        def poll_events
          return [] unless @handle

          raw_events = Metaco.poll_events(@handle)
          raw_events.filter_map { |event| convert_event(event) }
        end

        def poll_events_raw
          return [] unless @handle

          Metaco.poll_events(@handle)
        end

        def should_close?
          return false unless @handle

          Metaco.should_close?(@handle)
        end

        def close
          return unless @handle

          Metaco.window_destroy(@handle)
          @handle = nil
        end

        def set_pixels(buffer, width, height)
          return unless @handle

          Metaco.set_pixels(@handle, buffer, width, height)
          Metaco.present(@handle)
        end

        def metal_available?
          return false unless @handle

          Metaco.metal_compute_available?(@handle)
        end

        def native_handle
          @handle
        end

        private

        def convert_event(raw)
          type = raw[:type]

          case type
          when :key_press
            Event.new(:key_press, key: raw[:key], char: raw[:char])
          when :key_release
            Event.new(:key_release, key: raw[:key])
          when :mouse_press
            Event.new(:mouse_press, x: raw[:x], y: raw[:y], button: raw[:button])
          when :mouse_release
            Event.new(:mouse_release, x: raw[:x], y: raw[:y], button: raw[:button])
          when :mouse_move
            Event.new(:mouse_move, x: raw[:x], y: raw[:y])
          when :resize
            Event.new(:resize, width: raw[:width], height: raw[:height])
          else
            nil
          end
        end
      end
    end
  end
end
