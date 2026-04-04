# frozen_string_literal: true

module RBGL
  module GUI
    class Window
      class RenderLoop
        attr_reader :fps

        def initialize(time_source: -> { Time.now })
          @time_source = time_source
          @fps = 0
          @running = false
        end

        def run(backend:, context:, process_events:, &frame_callback)
          @running = true
          start_time = @time_source.call
          last_time = start_time
          frame_count = 0

          while @running && !backend.should_close?
            current_time = @time_source.call
            delta_time = current_time - last_time
            last_time = current_time

            process_events.call
            frame_callback&.call(context, delta_time)
            backend.present(context.framebuffer)

            frame_count += 1
            elapsed = current_time - start_time
            @fps = frame_count / elapsed if elapsed.positive?
          end
        end

        def stop
          @running = false
        end
      end
    end
  end
end
