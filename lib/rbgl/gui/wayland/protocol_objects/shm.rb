# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class Shm < WaylandObject
        def create_pool(fd, size)
          pool_id = @connection.allocate_id
          @connection.send_request_with_fd(@id, 0, Arguments.new_id(pool_id), Arguments.int(size), fd)
          @connection.register_object(ShmPool.new(@connection, pool_id))
        end
      end

      class ShmPool < WaylandObject
        def create_buffer(offset, width, height, stride, format)
          buffer_id = @connection.allocate_id
          format_val = case format
                       when :argb8888 then 0
                       when :xrgb8888 then 1
                       else 0
                       end
          send_request(
            0,
            Arguments.new_id(buffer_id),
            Arguments.int(offset),
            Arguments.int(width),
            Arguments.int(height),
            Arguments.int(stride),
            Arguments.uint(format_val)
          )
          @connection.register_object(WlBuffer.new(@connection, buffer_id))
        end

        def destroy
          send_request(1)
        end
      end

      class WlBuffer < WaylandObject
        def initialize(connection, id)
          super
          @busy = false
          @destroy_requested = false
          @destroyed = false
          @release_callbacks = []
        end

        def on_release(&block)
          @release_callbacks << block if block
        end

        def mark_in_use
          @busy = true
        end

        def available?
          !@busy && !@destroy_requested && !@destroyed
        end

        def busy?
          @busy
        end

        def handle_release
          @busy = false
          @release_callbacks.each(&:call)
          finalize_destroy if @destroy_requested
        end

        def destroy
          return if @destroyed || @destroy_requested

          if @busy
            @destroy_requested = true
          else
            finalize_destroy
          end
        end

        private

        def finalize_destroy
          return if @destroyed

          send_request(0)
          @destroyed = true
        end
      end

      class ShmBuffer
        attr_reader :wl_buffer

        def initialize(file, pool, wl_buffer)
          @file = file
          @pool = pool
          @wl_buffer = wl_buffer
          @destroy_requested = false
          @destroyed = false
          @file.binmode
          @file.seek(0)
          @wl_buffer.on_release { handle_release }
        end

        def write(data)
          @file.seek(0)
          @file.write(data)
          @file.flush
        end

        def available?
          @wl_buffer.available?
        end

        def mark_in_use
          @wl_buffer.mark_in_use
        end

        def id
          @wl_buffer.id
        end

        def destroy
          return if @destroyed

          @destroy_requested = true
          @wl_buffer.destroy
          finalize_destroy unless @wl_buffer.busy?
        end

        private

        def handle_release
          finalize_destroy if @destroy_requested
        end

        def finalize_destroy
          return if @destroyed

          @pool.destroy
          @file.close unless @file.closed?
          @destroyed = true
        end
      end
    end
  end
end
