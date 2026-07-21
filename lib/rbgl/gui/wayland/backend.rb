# frozen_string_literal: true

require_relative "connection"
require "tempfile"

module RBGL
  module GUI
    module Wayland
      class Backend < GUI::Backend
        BUFFER_WAIT_TIMEOUT = 0.25
        BUFFER_POLL_INTERVAL = 0.016

        def initialize(width, height, title = "RBGL", env: ENV, roundtrip_timeout: Connection::DEFAULT_ROUNDTRIP_TIMEOUT)
          super(width, height, title)
          @connection = Connection.new(env: env, roundtrip_timeout: roundtrip_timeout)
          @window = nil
          setup_window(width, height, title)
        rescue StandardError
          @connection&.close
          raise
        end

        private def setup_window(w, h, t)
          surface = @connection.compositor.create_surface
          xdg_surface = @connection.xdg_wm_base.get_xdg_surface(surface)
          toplevel = xdg_surface.get_toplevel
          toplevel.set_title(t)

          @window = {
            surface: surface,
            xdg_surface: xdg_surface,
            toplevel: toplevel,
            buffers: [],
            shm_buffer: nil,
            width: w,
            height: h,
            should_close: false
          }

          surface.commit
          @connection.flush
          wait_for_initial_configure(xdg_surface)

          buffers = create_shm_buffers(w, h)
          @window[:buffers] = buffers
          @window[:shm_buffer] = buffers.first
        end

        def present(framebuffer)
          window = @window
          return false unless window

          buffer_object = wait_for_available_buffer(window)
          return false unless buffer_object

          buffer = convert_to_wayland_format(framebuffer)
          buffer_object.write(buffer)

          window[:surface].damage(0, 0, framebuffer.width, framebuffer.height)
          window[:surface].attach(buffer_object, 0, 0)
          buffer_object.mark_in_use
          window[:shm_buffer] = buffer_object
          window[:surface].commit
          @connection.flush
          true
        end

        def poll_events
          @connection.dispatch_pending.filter_map { |event| convert_event(event) }
        end

        def resize(width, height)
          super
          window = @window
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
          @window.nil? || @window[:should_close]
        end

        def close
          window = @window
          return unless window

          window[:should_close] = true
          window[:toplevel].destroy
          window[:xdg_surface].destroy
          window[:surface].destroy
          window.fetch(:buffers, [window[:shm_buffer]].compact).each { |buffer| buffer.destroy(force: true) }
          @connection.flush
          @window = nil
          @connection.close
        end

        private

        def convert_to_wayland_format(framebuffer)
          framebuffer.to_bgra_bytes
        end

        def convert_event(raw)
          window = window_for_event(raw[:surface_id] || raw[:object_id])
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
          when :key_press, :key_release
            Event.new(raw[:type], key: raw[:key], keycode: raw[:keycode])
          when :pointer_motion
            Event.new(:mouse_move, x: raw[:x], y: raw[:y])
          when :pointer_button_press
            Event.new(:mouse_press, button: raw[:button], x: raw[:x], y: raw[:y])
          when :pointer_button_release
            Event.new(:mouse_release, button: raw[:button], x: raw[:x], y: raw[:y])
          when :pointer_axis
            Event.new(:mouse_scroll, x: raw[:x], y: raw[:y], axis: raw[:axis], value: raw[:value])
          end
        end

        def window_for_event(object_id)
          return unless @window
          return @window if @window[:toplevel].id == object_id || @window[:surface].id == object_id
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
          pool = @connection.shm.create_pool(file, size)
          buffer = pool.create_buffer(0, width, height, width * 4, :xrgb8888)

          ShmBuffer.new(file, pool, buffer)
        end

        def create_anonymous_file(size)
          file = Tempfile.new("rbgl-wayland")
          file.binmode
          file.chmod(0o600)
          file.truncate(size)
          file.unlink
          file
        end

        def wait_for_initial_configure(xdg_surface)
          configured = @connection.wait_until { xdg_surface.configured? }
          return if configured

          raise GUI::BackendUnavailable, "Wayland compositor did not configure the surface"
        end

      end
    end
  end
end
