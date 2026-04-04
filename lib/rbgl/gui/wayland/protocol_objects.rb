# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      TypedArgument = Struct.new(:type, :value)

      module Arguments
        module_function

        def uint(value)
          TypedArgument.new(:uint, Integer(value))
        end

        def int(value)
          TypedArgument.new(:int, Integer(value))
        end

        def fixed(value)
          TypedArgument.new(:fixed, Float(value))
        end

        def string(value)
          TypedArgument.new(:string, value.to_s)
        end

        def object(value)
          object_id = value.respond_to?(:id) ? value.id : value
          TypedArgument.new(:object, Integer(object_id))
        end

        def new_id(value)
          TypedArgument.new(:new_id, Integer(value))
        end
      end

      class WaylandObject
        attr_reader :id, :connection

        def initialize(connection, id)
          @connection = connection
          @id = id
        end

        def send_request(opcode, *args)
          @connection.send_request(@id, opcode, *args)
        end
      end

      class Display < WaylandObject
        def initialize(connection)
          super(connection, 1)
        end

        def sync
          callback_id = @connection.allocate_id
          send_request(0, Arguments.new_id(callback_id))
          @connection.register_object(Callback.new(@connection, callback_id))
        end

        def get_registry
          registry_id = @connection.allocate_id
          send_request(1, Arguments.new_id(registry_id))
          @connection.register_object(Registry.new(@connection, registry_id))
        end
      end

      class Registry < WaylandObject
        def bind(name, interface, version)
          new_id = @connection.allocate_id
          send_request(
            0,
            Arguments.uint(name),
            Arguments.string(interface),
            Arguments.uint(version),
            Arguments.new_id(new_id)
          )
          new_id
        end
      end

      class Callback < WaylandObject
        def initialize(connection, id)
          super
          @done = false
        end

        def done?
          @done
        end

        def handle_done
          @done = true
        end
      end

      class Compositor < WaylandObject
        def create_surface
          surface_id = @connection.allocate_id
          send_request(0, Arguments.new_id(surface_id))
          @connection.register_object(Surface.new(@connection, surface_id))
        end
      end

      class Surface < WaylandObject
        def attach(buffer, x, y)
          send_request(1, Arguments.object(buffer), Arguments.int(x), Arguments.int(y))
        end

        def damage(x, y, width, height)
          send_request(2, Arguments.int(x), Arguments.int(y), Arguments.int(width), Arguments.int(height))
        end

        def commit
          send_request(6)
        end

        def destroy
          send_request(0)
        end
      end

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

      class XdgWmBase < WaylandObject
        def get_xdg_surface(surface)
          xdg_surface_id = @connection.allocate_id
          send_request(2, Arguments.new_id(xdg_surface_id), Arguments.object(surface))
          @connection.register_object(XdgSurface.new(@connection, xdg_surface_id))
        end

        def pong(serial)
          send_request(3, Arguments.uint(serial))
        end
      end

      class XdgSurface < WaylandObject
        def get_toplevel
          toplevel_id = @connection.allocate_id
          send_request(1, Arguments.new_id(toplevel_id))
          @connection.register_object(XdgToplevel.new(@connection, toplevel_id))
        end

        def ack_configure(serial)
          send_request(4, Arguments.uint(serial))
        end

        def destroy
          send_request(0)
        end
      end

      class XdgToplevel < WaylandObject
        def set_title(title)
          send_request(2, Arguments.string(title))
        end

        def destroy
          send_request(0)
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
