# frozen_string_literal: true

require_relative "window/render_loop"
require_relative "window/event_dispatcher"

module RBGL
  module GUI
    class Window
      attr_reader :context, :backend, :width, :height

      def initialize(width:, height:, title: "RBGL", backend: :auto, target_fps: 60, **options)
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
        @render_loop = RenderLoop.new(target_fps: target_fps)
        @closed = false
      end

      def on(event_type, &block)
        validate_event_handler!(event_type, block)
        @event_handlers[event_type] << block
      end

      def run(&frame_callback)
        raise RuntimeError, "Window#run is one-shot and cannot be called after the window is closed" if @closed

        @render_loop.run(
          backend: @backend,
          context: @context,
          process_events: method(:process_events),
          &frame_callback
        )
      ensure
        close if @backend
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
        @backend.respond_to?(:metal_available?) && @backend.metal_available?
      end

      def native_handle
        @backend.native_handle if @backend.respond_to?(:native_handle)
      end

      def should_close?
        @backend.should_close?
      end

      def poll_events_raw
        events = @backend.poll_events_raw
        Array(events).each do |event|
          next unless event.respond_to?(:[]) && event[:type] == :resize

          apply_resize(Event.new(:resize, width: event[:width], height: event[:height]))
        end
        events
      end

      def close
        return if @closed

        @render_loop.stop
        @backend.close
      ensure
        @closed = true
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
        @backend.resize(event.width, event.height)
        @context.resize(width: event.width, height: event.height)
        @width = event.width
        @height = event.height
      end

      def validate_event_handler!(event_type, block)
        return if block

        raise ArgumentError, "A block is required for #{event_type} handlers"
      end
    end
  end
end
