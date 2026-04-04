# frozen_string_literal: true

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

        @running = false
        @frame_callback = nil
        @last_time = Time.now
        @fps = 0
        @frame_count = 0
        @event_handlers = Hash.new { |h, k| h[k] = [] }
      end

      def on(event_type, &block)
        @event_handlers[event_type] << block
      end

      def on_key(&block)
        @backend.on_key(&block)
      end

      def on_mouse(&block)
        @backend.on_mouse(&block)
      end

      def on_resize(&block)
        @backend.on_resize(&block)
      end

      def run(&frame_callback)
        @frame_callback = frame_callback
        @running = true
        @start_time = Time.now
        @last_time = @start_time

        while @running && !@backend.should_close?
          current_time = Time.now
          delta_time = current_time - @last_time
          @last_time = current_time

          process_events

          @frame_callback&.call(@context, delta_time)

          @backend.present(@context.framebuffer)

          @frame_count += 1
          elapsed = current_time - @start_time
          @fps = @frame_count / elapsed if elapsed > 0
        end

        @backend.close
      end

      def stop
        @running = false
      end

      def present_framebuffer(framebuffer = nil)
        fb = framebuffer || @context.framebuffer
        @backend.present(fb)
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

      attr_reader :fps

      private

      def build_backend(backend, width:, height:, title:, **options)
        BackendFactory.build(backend, width: width, height: height, title: title, **options)
      end

      def process_events
        Array(@backend.poll_events).each do |event|
          next unless event.is_a?(Event)

          apply_resize(event) if event.type == :resize
          @backend.dispatch_event(event)
          @event_handlers[event.type].each { |handler| handler.call(event) }
        end
      end

      def apply_resize(event)
        @width = event.width
        @height = event.height
        @context.resize(width: event.width, height: event.height)
        @backend.resize(event.width, event.height)
      end
    end
  end
end
