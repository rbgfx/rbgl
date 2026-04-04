# frozen_string_literal: true

module RBGL
  module GUI
    class BackendUnavailable < StandardError
    end

    class BackendSelectionError < ArgumentError
    end

    class Backend
      attr_reader :width, :height, :title

      def initialize(width, height, title = "RBGL")
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
    end
  end
end
