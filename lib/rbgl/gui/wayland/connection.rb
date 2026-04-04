# frozen_string_literal: true

require "socket"
require_relative "protocol_objects"
require_relative "codec"
require_relative "event_dispatcher"
require_relative "global_binder"

module RBGL
  module GUI
    module Wayland
      class Connection
        DEFAULT_ROUNDTRIP_TIMEOUT = 1.0
        ROUNDTRIP_POLL_INTERVAL = 0.01

        attr_reader :compositor, :shm, :xdg_wm_base, :registry, :globals

        def initialize(env: ENV, socket_path: nil, roundtrip_timeout: DEFAULT_ROUNDTRIP_TIMEOUT)
          @env = env
          @roundtrip_timeout = roundtrip_timeout
          @socket = UNIXSocket.new(resolve_socket_path(socket_path))
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

        def object_for(object_id)
          @objects[object_id]
        end

        def store_global(interface, name:, version:)
          @globals[interface] = { name: name, version: version }
        end

        def queue_event(event)
          @pending_events << event
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
          pump_events(timeout: 0)

          events = @pending_events
          @pending_events = []
          events
        end

        def pump_events(timeout: nil)
          ready = IO.select([@socket], nil, nil, timeout)
          return 0 unless ready

          loop do
            header = @socket.read(8)
            break unless header && header.bytesize == 8

            object_id, size_and_opcode = header.unpack("VV")
            size = size_and_opcode >> 16
            opcode = size_and_opcode & 0xFFFF
            payload = size > 8 ? @socket.read(size - 8) : ""

            handle_event(object_id, opcode, payload)
            break unless IO.select([@socket], nil, nil, 0)
          end

          @pending_events.length
        end

        def roundtrip
          callback = @display.sync
          @objects[callback.id] = callback
          flush
          deadline = monotonic_time + @roundtrip_timeout

          until callback.done?
            raise BackendUnavailable, "Wayland roundtrip timed out" if monotonic_time >= deadline

            pump_events(timeout: roundtrip_poll_interval(deadline))
          end
        end

        private

        def resolve_socket_path(socket_path = nil)
          socket_path ||= @env["WAYLAND_DISPLAY"] || "wayland-0"
          return socket_path if socket_path.start_with?("/")

          runtime_dir = @env["XDG_RUNTIME_DIR"] || "/run/user/#{Process.uid}"
          File.join(runtime_dir, socket_path)
        end

        def roundtrip_poll_interval(deadline)
          [deadline - monotonic_time, ROUNDTRIP_POLL_INTERVAL].min.clamp(0.0, ROUNDTRIP_POLL_INTERVAL)
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end

        def handle_event(object_id, opcode, payload)
          event_dispatcher.handle_event(object_id, opcode, payload)
        end

        def bind_globals
          bound = global_binder.bind!(@registry, @globals)
          @compositor = bound[:compositor]
          @shm = bound[:shm]
          @xdg_wm_base = bound[:xdg_wm_base]
          flush
          roundtrip
        end

        def pack_args(args)
          codec.pack_args(args)
        end

        def pad_length(length)
          codec.pad_length(length)
        end

        def codec
          @codec ||= Codec.new
        end

        def event_dispatcher
          @event_dispatcher ||= EventDispatcher.new(self, codec: codec)
        end

        def global_binder
          @global_binder ||= GlobalBinder.new(self)
        end
      end
    end
  end
end
