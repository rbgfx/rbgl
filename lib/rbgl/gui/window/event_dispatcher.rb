# frozen_string_literal: true

module RBGL
  module GUI
    class Window
      class EventDispatcher
        def initialize(backend:, event_handlers:, on_resize:)
          @backend = backend
          @event_handlers = event_handlers
          @on_resize = on_resize
        end

        def process
          Array(@backend.poll_events).each do |event|
            next unless event.is_a?(Event)

            @on_resize.call(event) if event.type == :resize
            @backend.dispatch_event(event)
            @event_handlers[event.type].each { |handler| handler.call(event) }
          end
        end
      end
    end
  end
end
