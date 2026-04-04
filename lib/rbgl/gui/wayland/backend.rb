# frozen_string_literal: true

require_relative "connection"

module RBGL
  module GUI
    module Wayland
      class Backend < GUI::Backend
        BUFFER_WAIT_TIMEOUT = 0.25
        BUFFER_POLL_INTERVAL = 0.016

        def initialize(width, height, title = "RBGL")
          super
          @connection = Connection.new
          @windows = {}
          setup_window(width, height, title)
        end

        private def setup_window(w, h, t)
          surface = @connection.compositor.create_surface
          xdg_surface = @connection.xdg_wm_base.get_xdg_surface(surface)
          toplevel = xdg_surface.get_toplevel
          toplevel.set_title(t)

          buffers = create_shm_buffers(w, h)
          shm_buffer = buffers.first

          surface.attach(shm_buffer, 0, 0)
          shm_buffer.mark_in_use
          surface.commit
          @connection.flush

          handle = surface.id
          @windows[handle] = {
            surface: surface,
            xdg_surface: xdg_surface,
            toplevel: toplevel,
            buffers: buffers,
            shm_buffer: shm_buffer,
            width: w,
            height: h,
            should_close: false,
            pending_events: []
          }

          @handle = handle
        end

        def present(framebuffer)
          return unless @handle

          window = @windows[@handle]
          return unless window

          buffer_object = wait_for_available_buffer(window)
          return unless buffer_object

          buffer = convert_to_wayland_format(framebuffer)
          buffer_object.write(buffer)

          window[:surface].damage(0, 0, framebuffer.width, framebuffer.height)
          window[:surface].attach(buffer_object, 0, 0)
          buffer_object.mark_in_use
          window[:shm_buffer] = buffer_object
          window[:surface].commit
          @connection.flush
        end

        def poll_events
          @connection.dispatch_pending.filter_map { |event| convert_event(event) }
        end

        def resize(width, height)
          super
          return unless @handle

          window = @windows[@handle]
          return unless window
          return if window[:width] == width && window[:height] == height

          old_buffers = window.fetch(:buffers, [window[:shm_buffer]].compact)
          new_buffers = create_shm_buffers(width, height)
          window[:buffers] = new_buffers
          window[:shm_buffer] = new_buffers.first
          window[:width] = width
          window[:height] = height
          old_buffers.each(&:destroy)
        end

        def should_close?
          return false unless @handle

          @windows[@handle]&.[](:should_close) || false
        end

        def close
          return unless @handle

          window = @windows[@handle]
          return unless window

          window[:should_close] = true
          window[:toplevel].destroy
          window[:xdg_surface].destroy
          window[:surface].destroy
          window.fetch(:buffers, [window[:shm_buffer]].compact).each(&:destroy)
          @windows.delete(@handle)
          @handle = nil
        end

        private

        def convert_to_wayland_format(framebuffer)
          framebuffer.to_bgra_bytes
        end

        def convert_event(raw)
          window = window_for_event(raw[:object_id])
          return nil unless window

          case raw[:type]
          when :xdg_toplevel_close
            window[:should_close] = true
            Event.new(:close)
          when :xdg_toplevel_configure
            width = raw[:width]
            height = raw[:height]
            return nil unless width.positive? && height.positive?

            window[:width] = width
            window[:height] = height
            Event.new(:resize, width: width, height: height)
          end
        end

        def window_for_event(object_id)
          @windows.values.find { |window| window[:toplevel].id == object_id }
        end

        def next_available_buffer(window)
          window.fetch(:buffers, [window[:shm_buffer]].compact).find(&:available?)
        end

        def wait_for_available_buffer(window)
          deadline = monotonic_time + BUFFER_WAIT_TIMEOUT

          loop do
            buffer = next_available_buffer(window)
            return buffer if buffer
            return nil if abort_buffer_wait?(window, deadline)

            pump_connection(timeout: remaining_buffer_wait(deadline))
          end
        end

        def pump_connection(timeout:)
          if @connection.respond_to?(:pump_events)
            @connection.pump_events(timeout: timeout)
          else
            sleep(timeout)
          end
        end

        def abort_buffer_wait?(window, deadline)
          window[:should_close] || monotonic_time >= deadline
        end

        def remaining_buffer_wait(deadline)
          [deadline - monotonic_time, BUFFER_POLL_INTERVAL].min.clamp(0.0, BUFFER_POLL_INTERVAL)
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def create_shm_buffers(width, height, count = 2)
          Array.new(count) { create_shm_buffer(width, height) }
        end

        def create_shm_buffer(width, height)
          size = width * height * 4

          file = create_anonymous_file(size)
          pool = @connection.shm.create_pool(file.fileno, size)
          buffer = pool.create_buffer(0, width, height, width * 4, :argb8888)

          ShmBuffer.new(file, pool, buffer)
        end

        def create_anonymous_file(size)
          name = "rbgl-#{Process.pid}-#{rand(10000)}"
          path = "/dev/shm/#{name}"

          file = File.open(path, File::RDWR | File::CREAT | File::EXCL, 0o600)
          file.truncate(size)
          File.unlink(path)
          file
        rescue Errno::ENOENT
          require "tempfile"
          tmpfile = Tempfile.new("rbgl")
          tmpfile.truncate(size)
          tmpfile
        end
      end
    end
  end
end
