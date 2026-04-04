# frozen_string_literal: true

module RBGL
  module GUI
    class Window
      class RenderLoop
        DEFAULT_TIME_SOURCE = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }

        attr_reader :fps, :dropped_frames

        def initialize(time_source: DEFAULT_TIME_SOURCE)
          @time_source = time_source
          @fps = 0
          @dropped_frames = 0
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
            break if stop_requested?(backend)
            frame_callback&.call(context, delta_time)
            break if stop_requested?(backend)
            record_present_result(backend.present(context.framebuffer))

            frame_count += 1
            elapsed = current_time - start_time
            @fps = frame_count / elapsed if elapsed.positive?
          end
        end

        def record_present_result(result)
          @dropped_frames += 1 if result == false
          result
        end

        def stop
          @running = false
        end

        private

        def stop_requested?(backend)
          !@running || backend.should_close?
        end
      end
    end
  end
end
