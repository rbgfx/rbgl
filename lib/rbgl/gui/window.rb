# frozen_string_literal: true

require_relative "window/render_loop"
require_relative "window/event_dispatcher"

module RBGL
  module GUI
    class Window
      attr_reader :context, :backend, :width, :height

      def initialize(width:, height:, title: "RBGL", backend: :auto, **options)
        @width = width
        @height = height
        @title = title
        @context = Engine::Context.new(width: width, height: height)
        @backend = build_backend(backend, width: width, height: height, title: title, **options)
        @event_handlers = Hash.new { |h, k| h[k] = [] }
        @event_dispatcher = EventDispatcher.new(
          backend: @backend,
          event_handlers: @event_handlers,
          on_resize: method(:apply_resize)
        )
        @render_loop = RenderLoop.new
      end

      def on(event_type, &block)
        @event_handlers[event_type] << block
      end

      def on_key(&block)
        register_key_handler(:key_press, :press, &block)
        register_key_handler(:key_release, :release, &block)
      end

      def on_mouse(&block)
        register_mouse_handler(:mouse_press, :press, &block)
        register_mouse_handler(:mouse_release, :release, &block)
        register_mouse_handler(:mouse_move, :move, &block)
      end

      def on_resize(&block)
        on(:resize) { |event| block.call(event.width, event.height) }
      end

      def run(&frame_callback)
        @render_loop.run(
          backend: @backend,
          context: @context,
          process_events: method(:process_events),
          &frame_callback
        )
        @backend.close
      end

      def stop
        @render_loop.stop
      end

      def present_framebuffer(framebuffer = nil)
        fb = framebuffer || @context.framebuffer
        @render_loop.record_present_result(@backend.present(fb))
      end

      def set_pixels(buffer)
        @backend.set_pixels(buffer, @width, @height)
      end

      def metal_available?
        @backend.metal_available?
      end

      def native_handle
        @backend.native_handle
      end

      def should_close?
        @backend.should_close?
      end

      def poll_events_raw
        @backend.poll_events_raw
      end

      def close
        @backend.close
      end

      def fps
        @render_loop.fps
      end

      def dropped_frames
        @render_loop.dropped_frames
      end

      private

      def build_backend(backend, width:, height:, title:, **options)
        BackendFactory.build(backend, width: width, height: height, title: title, **options)
      end

      def process_events
        @event_dispatcher.process
      end

      def apply_resize(event)
        @width = event.width
        @height = event.height
        @context.resize(width: event.width, height: event.height)
        @backend.resize(event.width, event.height)
      end

      def register_key_handler(event_type, action, &block)
        on(event_type) { |event| block.call(event.key, action) }
      end

      def register_mouse_handler(event_type, action, &block)
        on(event_type) { |event| block.call(event.x, event.y, event[:button], action) }
      end
    end
  end
end
