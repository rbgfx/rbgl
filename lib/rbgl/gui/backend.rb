# frozen_string_literal: true

module RBGL
  module GUI
    class BackendUnavailable < StandardError
    end

    class BackendSelectionError < ArgumentError
    end

    class Backend
      attr_reader :width, :height, :title

      def initialize(width, height, title = "RBGL", **_options)
        @width = width
        @height = height
        @title = title
      end

      def present(_framebuffer)
        raise NotImplementedError
      end

      def poll_events
        raise NotImplementedError
      end

      def poll_events_raw
        poll_events.filter_map { |event| event.to_h if event.respond_to?(:to_h) }
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
        bytes = validate_rgba_buffer(buffer, width, height)
        present(Engine::Framebuffer.from_rgba_bytes(width, height, bytes))
      end

      protected

      def validate_rgba_buffer(buffer, width, height)
        bytes = String.try_convert(buffer)
        raise ArgumentError, "Pixel buffer must be a String" unless bytes

        expected_size = width * height * 4
        return bytes if bytes.bytesize == expected_size

        raise ArgumentError, "Pixel buffer size mismatch: expected #{expected_size}, got #{bytes.bytesize}"
      end
    end
  end
end
