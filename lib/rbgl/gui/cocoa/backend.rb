# frozen_string_literal: true

require_relative "key_mapper"

module RBGL
  module GUI
    module Cocoa
      METACO_AVAILABLE = begin
        require "metaco"
        true
      rescue LoadError
        false
      end

      class Backend < GUI::Backend
        def initialize(width, height, title = "RBGL", env: ENV, resizable: false, high_dpi: false, **_options)
          @env = env
          unless METACO_AVAILABLE
            raise LoadError, "metaco gem is required for Cocoa backend. Install it with: gem install metaco"
          end

          super(width, height, title)
          Metaco.init
          @handle = Metaco.window_create(width, height, title, resizable: resizable, high_dpi: high_dpi)
          @framebuffer_width, @framebuffer_height = Metaco.framebuffer_size(@handle)
        end

        def present(framebuffer)
          return false unless @handle

          bytes = framebuffer.to_rgba_bytes
          width = @framebuffer_width
          height = @framebuffer_height
          bytes = scale_pixels(bytes, framebuffer.width, framebuffer.height, width, height) if [width, height] != [framebuffer.width, framebuffer.height]
          Metaco.set_pixels(@handle, bytes, width, height)
          Metaco.present(@handle)
          true
        end

        def poll_events
          return [] unless @handle

          raw_events = Metaco.poll_events(@handle)
          raw_events.filter_map { |event| convert_event(event) }
        end

        def should_close?
          return true unless @handle

          Metaco.should_close?(@handle)
        end

        def close
          return unless @handle

          Metaco.window_destroy(@handle)
          @handle = nil
        end

        def set_pixels(buffer, width, height)
          return unless @handle

          bytes = validate_rgba_buffer(buffer, width, height)
          bytes = scale_pixels(bytes, width, height, @framebuffer_width, @framebuffer_height) if [width, height] != [@framebuffer_width, @framebuffer_height]
          Metaco.set_pixels(@handle, bytes, @framebuffer_width, @framebuffer_height)
          Metaco.present(@handle)
        end

        def resize(width, height)
          super
          @framebuffer_width, @framebuffer_height = Metaco.framebuffer_size(@handle)
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
            Event.new(:key_press, key: normalize_key(raw[:key], raw[:char]), keycode: raw[:key], char: raw[:char], modifiers: raw[:modifiers] || [])
          when :key_release
            Event.new(:key_release, key: normalize_key(raw[:key]), keycode: raw[:key], modifiers: raw[:modifiers] || [])
          when :mouse_press
            Event.new(:mouse_press, x: raw[:x], y: mouse_y(raw[:y]), button: raw[:button], modifiers: raw[:modifiers] || [])
          when :mouse_release
            Event.new(:mouse_release, x: raw[:x], y: mouse_y(raw[:y]), button: raw[:button], modifiers: raw[:modifiers] || [])
          when :mouse_move
            Event.new(:mouse_move, x: raw[:x], y: mouse_y(raw[:y]), modifiers: raw[:modifiers] || [])
          when :scroll
            Event.new(:scroll, dx: raw[:dx], dy: raw[:dy], modifiers: raw[:modifiers] || [])
          when :focus, :blur
            Event.new(type)
          when :resize
            Event.new(:resize, width: raw[:width], height: raw[:height],
                               framebuffer_width: raw[:framebuffer_width], framebuffer_height: raw[:framebuffer_height])
          else
            nil
          end
        end

        def normalize_key(key, char = nil)
          KeyMapper.key(key, char)
        end

        def mouse_y(y)
          @height ? @height - 1 - y : y
        end

        def scale_pixels(bytes, source_width, source_height, target_width, target_height)
          scaled = String.new(capacity: target_width * target_height * 4, encoding: Encoding::BINARY)
          target_height.times do |y|
            source_y = y * source_height / target_height
            target_width.times do |x|
              source_x = x * source_width / target_width
              scaled << bytes.byteslice(((source_y * source_width) + source_x) * 4, 4)
            end
          end
          scaled
        end
      end
    end
  end
end
