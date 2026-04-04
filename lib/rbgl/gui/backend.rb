# frozen_string_literal: true

module RBGL
  module GUI
    class Backend
      attr_reader :width, :height, :title

      def initialize(width, height, title = "RBGL")
        @width = width
        @height = height
        @title = title
        @key_callback = nil
        @mouse_callback = nil
        @resize_callback = nil
      end

      def present(_framebuffer)
        raise NotImplementedError
      end

      def poll_events
        raise NotImplementedError
      end

      def poll_events_raw
        []
      end

      def resize(width, height)
        @width = width
        @height = height
      end

      def should_close?
        raise NotImplementedError
      end

      def close
        raise NotImplementedError
      end

      def set_pixels(buffer, width, height)
        raise NotImplementedError
      end

      def metal_available?
        false
      end

      def native_handle
        nil
      end

      def on_key(&block)
        @key_callback = block
      end

      def on_mouse(&block)
        @mouse_callback = block
      end

      def on_resize(&block)
        @resize_callback = block
      end

      def dispatch_event(event)
        case event.type
        when :key_press, :key_release
          emit_key(event.key, event.type == :key_press ? :press : :release)
        when :mouse_press, :mouse_release, :mouse_move
          action = case event.type
                   when :mouse_press then :press
                   when :mouse_release then :release
                   else :move
                   end
          emit_mouse(event.x, event.y, event[:button], action)
        when :resize
          emit_resize(event.width, event.height)
        end
      end

      protected

      def emit_key(key, action)
        @key_callback&.call(key, action)
      end

      def emit_mouse(x, y, button, action)
        @mouse_callback&.call(x, y, button, action)
      end

      def emit_resize(width, height)
        @resize_callback&.call(width, height)
      end
    end
  end
end
