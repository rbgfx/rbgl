# frozen_string_literal: true

module RBGL
  module GUI
    class Window
      class RenderLoop
        DEFAULT_TIME_SOURCE = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
        DEFAULT_SLEEPER = ->(duration) { sleep(duration) }
        FPS_WINDOW_SECONDS = 1.0

        attr_reader :fps, :dropped_frames

        def initialize(time_source: DEFAULT_TIME_SOURCE, sleeper: DEFAULT_SLEEPER, target_fps: 60)
          @time_source = time_source
          @sleeper = sleeper
          @frame_interval = target_fps && (1.0 / validate_target_fps(target_fps))
          @fps = 0
          @dropped_frames = 0
          @running = false
          @frame_times = []
        end

        def run(backend:, context:, process_events:, &frame_callback)
          @running = true
          last_time = @time_source.call
          next_frame_deadline = @frame_interval && (last_time + @frame_interval)
          @frame_times.clear

          while @running && !backend.should_close?
            frame_started_at = @time_source.call
            delta_time = frame_started_at - last_time
            last_time = frame_started_at

            process_events.call
            break if stop_requested?(backend)
            frame_callback&.call(context, delta_time)
            break if stop_requested?(backend)
            record_present_result(backend.present(context.framebuffer))

            frame_finished_at = @time_source.call
            record_frame(frame_finished_at)
            throttle(next_frame_deadline, frame_finished_at)
            next_frame_deadline += @frame_interval if next_frame_deadline
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

        def record_frame(timestamp)
          @frame_times << timestamp
          cutoff = timestamp - FPS_WINDOW_SECONDS
          @frame_times.shift while @frame_times.length > 2 && @frame_times.first < cutoff
          return @fps = 0 if @frame_times.length < 2

          elapsed = @frame_times.last - @frame_times.first
          @fps = elapsed.positive? ? (@frame_times.length - 1) / elapsed : 0
        end

        def throttle(deadline, frame_finished_at)
          return unless deadline

          remaining = deadline - frame_finished_at
          @sleeper.call(remaining) if remaining.positive?
        end

        def validate_target_fps(target_fps)
          fps = Float(target_fps)
          return fps if fps.positive?

          raise ArgumentError, "target_fps must be positive or nil"
        rescue ArgumentError, TypeError
          raise ArgumentError, "target_fps must be positive or nil"
        end

        def stop_requested?(backend)
          !@running || backend.should_close?
        end
      end
    end
  end
end
