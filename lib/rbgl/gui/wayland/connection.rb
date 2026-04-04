# frozen_string_literal: true

require "socket"

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

      class Connection
        attr_reader :compositor, :shm, :xdg_wm_base, :registry

        def initialize
          socket_path = ENV["WAYLAND_DISPLAY"] || "wayland-0"
          unless socket_path.start_with?("/")
            runtime_dir = ENV["XDG_RUNTIME_DIR"] || "/run/user/#{Process.uid}"
            socket_path = File.join(runtime_dir, socket_path)
          end

          @socket = UNIXSocket.new(socket_path)
          @objects = {}
          @next_id = 2
          @globals = {}
          @pending_events = []

          @display = Display.new(self)
          register_object(@display)

          @registry = @display.get_registry
          flush
          roundtrip

          bind_globals
        end

        def allocate_id
          id = @next_id
          @next_id += 1
          id
        end

        def register_object(object)
          @objects[object.id] = object
          object
        end

        def send_request(object_id, opcode, *args)
          payload = pack_args(args)
          header = [object_id, (payload.bytesize + 8) << 16 | opcode].pack("VV")
          @socket.write(header + payload)
        end

        def send_request_with_fd(object_id, opcode, *args, fd)
          payload = pack_args(args)
          header = [object_id, (payload.bytesize + 8) << 16 | opcode].pack("VV")

          @socket.sendmsg(header + payload, 0, nil, Socket::AncillaryData.unix_rights(fd))
        end

        def flush
          @socket.flush
        end

        def dispatch_pending
          while IO.select([@socket], nil, nil, 0)
            header = @socket.read(8)
            break unless header && header.bytesize == 8

            object_id, size_and_opcode = header.unpack("VV")
            size = size_and_opcode >> 16
            opcode = size_and_opcode & 0xFFFF

            payload = size > 8 ? @socket.read(size - 8) : ""
            handle_event(object_id, opcode, payload)
          end

          events = @pending_events
          @pending_events = []
          events
        end

        def roundtrip
          callback = @display.sync
          @objects[callback.id] = callback
          flush

          until callback.done?
            dispatch_pending
            sleep 0.001
          end
        end

        private

        def handle_event(object_id, opcode, payload)
          obj = @objects[object_id]

          case obj
          when Registry
            handle_registry_event(opcode, payload)
          when Callback
            obj.handle_done if opcode == 0
          when WlBuffer
            obj.handle_release if opcode == 0
          when XdgWmBase
            handle_xdg_wm_base_event(obj, opcode, payload)
          when XdgSurface
            handle_xdg_surface_event(obj, opcode, payload)
          when XdgToplevel
            handle_xdg_toplevel_event(object_id, opcode, payload)
          end
        end

        def bind_globals
          if @globals["wl_compositor"]
            g = @globals["wl_compositor"]
            id = @registry.bind(g[:name], "wl_compositor", [g[:version], 4].min)
            @compositor = register_object(Compositor.new(self, id))
          end

          if @globals["wl_shm"]
            g = @globals["wl_shm"]
            id = @registry.bind(g[:name], "wl_shm", [g[:version], 1].min)
            @shm = register_object(Shm.new(self, id))
          end

          if @globals["xdg_wm_base"]
            g = @globals["xdg_wm_base"]
            id = @registry.bind(g[:name], "xdg_wm_base", [g[:version], 2].min)
            @xdg_wm_base = register_object(XdgWmBase.new(self, id))
          end

          flush
          roundtrip
        end

        def pack_args(args)
          result = String.new
          args.each do |arg|
            case arg
            when TypedArgument
              result << pack_typed_argument(arg)
            when Integer
              result << [arg].pack("V")
            when String
              len = arg.bytesize + 1
              result << [len].pack("V")
              result << arg << "\x00"
              result << "\x00" * ((4 - len % 4) % 4)
            when Float
              result << [(arg * 256).to_i].pack("V")
            end
          end
          result
        end

        def pad_length(len)
          ((len + 3) / 4) * 4
        end

        def pack_typed_argument(arg)
          case arg.type
          when :uint, :object, :new_id
            [arg.value].pack("V")
          when :int
            [arg.value].pack("l<")
          when :fixed
            [(arg.value * 256).round].pack("l<")
          when :string
            len = arg.value.bytesize + 1
            [len].pack("V") + arg.value + "\x00" + ("\x00" * ((4 - len % 4) % 4))
          else
            raise ArgumentError, "Unsupported Wayland argument type: #{arg.type}"
          end
        end

        def handle_registry_event(opcode, payload)
          return unless opcode == 0

          name = payload[0, 4].unpack1("V")
          interface_len = payload[4, 4].unpack1("V")
          interface = payload[8, interface_len - 1]
          version = payload[8 + pad_length(interface_len), 4].unpack1("V")
          @globals[interface] = { name: name, version: version }
        end

        def handle_xdg_wm_base_event(obj, opcode, payload)
          return unless opcode == 0

          obj.pong(payload.unpack1("V"))
          flush
        end

        def handle_xdg_surface_event(obj, opcode, payload)
          return unless opcode == 0

          obj.ack_configure(payload.unpack1("V"))
          flush
        end

        def handle_xdg_toplevel_event(object_id, opcode, payload)
          case opcode
          when 0
            width, height = payload[0, 8].unpack("l<l<")
            @pending_events << {
              type: :xdg_toplevel_configure,
              object_id: object_id,
              width: width,
              height: height
            }
          when 1
            @pending_events << { type: :xdg_toplevel_close, object_id: object_id }
          end
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
