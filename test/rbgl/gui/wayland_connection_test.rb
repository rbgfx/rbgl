# frozen_string_literal: true

require_relative "../../test_helper"
require "rbgl/gui/wayland/backend"
require "rbgl/gui/wayland/connection"
require "socket"
require "tempfile"

class WaylandProtocolObjectsTest < Test::Unit::TestCase
  class RecordingConnection
    attr_reader :requests, :fd_requests

    def initialize(allocated_ids)
      @allocated_ids = allocated_ids
      @requests = []
      @fd_requests = []
    end

    def allocate_id
      @allocated_ids.shift
    end

    def send_request(object_id, opcode, *args)
      @requests << [object_id, opcode, args.map { |arg| normalize(arg) }]
    end

    def send_request_with_fd(object_id, opcode, *args, fd)
      @fd_requests << [object_id, opcode, args.map { |arg| normalize(arg) }, fd]
    end

    def register_object(object)
      object
    end

    private

    def normalize(arg)
      return [arg.type, arg.value] if arg.is_a?(RBGL::GUI::Wayland::TypedArgument)

      arg
    end
  end

  test "display creates callback and registry objects" do
    connection = RecordingConnection.new([10, 11])
    display = RBGL::GUI::Wayland::Display.new(connection)

    callback = display.sync
    registry = display.get_registry

    assert_equal 10, callback.id
    assert_equal 11, registry.id
    assert_equal [
      [1, 0, [[:new_id, 10]]],
      [1, 1, [[:new_id, 11]]]
    ], connection.requests
  end

  test "protocol objects send expected requests" do
    connection = RecordingConnection.new([21, 22, 23, 24, 25, 26])
    registry = RBGL::GUI::Wayland::Registry.new(connection, 2)
    compositor = RBGL::GUI::Wayland::Compositor.new(connection, 3)
    shm = RBGL::GUI::Wayland::Shm.new(connection, 4)
    xdg_wm_base = RBGL::GUI::Wayland::XdgWmBase.new(connection, 5)

    bound_id = registry.bind(1, "wl_compositor", 4)
    surface = compositor.create_surface
    file = Tempfile.new("rbgl-wayland-fd")
    pool = shm.create_pool(file, 64)
    xdg_surface = xdg_wm_base.get_xdg_surface(surface)
    toplevel = xdg_surface.get_toplevel

    surface.attach(pool.create_buffer(0, 4, 4, 16, :argb8888), 0, 0)
    surface.damage(1, 2, 3, 4)
    surface.commit
    surface.destroy
    xdg_wm_base.pong(77)
    xdg_surface.ack_configure(88)
    xdg_surface.destroy
    toplevel.set_title("RBGL")
    toplevel.destroy
    pool.destroy

    assert_equal 21, bound_id
    assert_equal 22, surface.id
    assert_equal 23, pool.id
    assert_equal 24, xdg_surface.id
    assert_equal 25, toplevel.id
    assert_equal [4, 0, [[:new_id, 23], [:int, 64]], file], connection.fd_requests.first
    assert_equal [
      [2, 0, [[:uint, 1], [:string, "wl_compositor"], [:uint, 4], [:new_id, 21]]],
      [3, 0, [[:new_id, 22]]],
      [5, 2, [[:new_id, 24], [:object, 22]]],
      [24, 1, [[:new_id, 25]]],
      [23, 0, [[:new_id, 26], [:int, 0], [:int, 4], [:int, 4], [:int, 16], [:uint, 0]]],
      [22, 1, [[:object, 26], [:int, 0], [:int, 0]]],
      [22, 2, [[:int, 1], [:int, 2], [:int, 3], [:int, 4]]],
      [22, 6, []],
      [22, 0, []],
      [5, 3, [[:uint, 77]]],
      [24, 4, [[:uint, 88]]],
      [24, 0, []],
      [25, 2, [[:string, "RBGL"]]],
      [25, 0, []],
      [23, 1, []]
    ], connection.requests
  ensure
    file&.close!
  end

  test "callback tracks done state" do
    callback = RBGL::GUI::Wayland::Callback.new(Object.new, 1)

    assert_false callback.done?

    callback.handle_done

    assert_true callback.done?
  end

  test "seat creates and releases pointer and keyboard objects from capabilities" do
    connection = RecordingConnection.new([31, 32])
    seat = RBGL::GUI::Wayland::Seat.new(connection, 30, version: 5)

    seat.handle_capabilities(3)

    assert_equal 31, seat.pointer.id
    assert_equal 32, seat.keyboard.id
    assert_equal [
      [30, 0, [[:new_id, 31]]],
      [30, 1, [[:new_id, 32]]]
    ], connection.requests

    seat.handle_capabilities(0)

    assert_nil seat.pointer
    assert_nil seat.keyboard
    assert_equal [31, 1, []], connection.requests[-2]
    assert_equal [32, 0, []], connection.requests[-1]
  end

  test "seat input objects only send release requests when supported" do
    connection = RecordingConnection.new([41, 42])
    seat = RBGL::GUI::Wayland::Seat.new(connection, 40, version: 2)

    seat.handle_capabilities(3)
    seat.handle_capabilities(0)
    seat.destroy

    assert_equal [
      [40, 0, [[:new_id, 41]]],
      [40, 1, [[:new_id, 42]]]
    ], connection.requests
  end
end

class WaylandConnectionTest < Test::Unit::TestCase
  class SpyRegistry
    attr_reader :id, :bind_calls

    def initialize(id, allocated_ids)
      @id = id
      @allocated_ids = allocated_ids
      @bind_calls = []
    end

    def bind(name, interface, version)
      @bind_calls << [name, interface, version]
      @allocated_ids.shift
    end
  end

  test "bind_globals uses registry allocated object ids" do
    allocated_ids = [11, 12, 13]
    registry = SpyRegistry.new(7, allocated_ids.dup)
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@registry, registry)
    connection.instance_variable_set(
      :@globals,
      {
        "wl_compositor" => { name: 1, version: 5 },
        "wl_shm" => { name: 2, version: 1 },
        "xdg_wm_base" => { name: 3, version: 4 }
      }
    )
    connection.instance_variable_set(:@objects, { registry.id => registry })

    connection.define_singleton_method(:flush) {}
    connection.define_singleton_method(:roundtrip) {}

    connection.send(:bind_globals)

    assert_equal [
      [1, "wl_compositor", 4],
      [2, "wl_shm", 1],
      [3, "xdg_wm_base", 2]
    ], registry.bind_calls
    assert_equal 11, connection.compositor.id
    assert_equal 12, connection.shm.id
    assert_equal 13, connection.xdg_wm_base.id
  end

  test "bind_globals raises when required globals are missing" do
    registry = SpyRegistry.new(7, [11, 12, 13])
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@registry, registry)
    connection.instance_variable_set(
      :@globals,
      {
        "wl_compositor" => { name: 1, version: 5 },
        "wl_shm" => { name: 2, version: 1 }
      }
    )
    connection.instance_variable_set(:@objects, { registry.id => registry })

    connection.define_singleton_method(:flush) {}
    connection.define_singleton_method(:roundtrip) {}

    error = assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(:bind_globals)
    end

    assert_includes error.message, "xdg_wm_base"
  end

  test "bind_globals binds an optional seat when advertised" do
    allocated_ids = [11, 12, 13, 14]
    registry = SpyRegistry.new(7, allocated_ids.dup)
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@registry, registry)
    connection.instance_variable_set(
      :@globals,
      {
        "wl_compositor" => { name: 1, version: 5 },
        "wl_shm" => { name: 2, version: 1 },
        "xdg_wm_base" => { name: 3, version: 4 },
        "wl_seat" => { name: 4, version: 7 }
      }
    )
    connection.instance_variable_set(:@objects, { registry.id => registry })
    connection.define_singleton_method(:flush) {}
    connection.define_singleton_method(:roundtrip) {}

    connection.send(:bind_globals)

    assert_equal [4, "wl_seat", 5], registry.bind_calls.last
    assert_equal 14, connection.seat.id
  end

  test "handle_event queues toplevel close events" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    toplevel = RBGL::GUI::Wayland::XdgToplevel.allocate

    connection.instance_variable_set(:@objects, { 21 => toplevel })
    connection.instance_variable_set(:@pending_events, [])

    connection.send(:handle_event, 21, 1, +"")

    assert_equal [{ type: :xdg_toplevel_close, object_id: 21 }], connection.instance_variable_get(:@pending_events)
  end

  test "handle_event records globals via registry object and replies to ping and configure" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    registry = RBGL::GUI::Wayland::Registry.allocate
    xdg_wm_base = RBGL::GUI::Wayland::XdgWmBase.allocate
    xdg_surface = RBGL::GUI::Wayland::XdgSurface.new(connection, 9)

    connection.instance_variable_set(:@objects, {
      7 => registry,
      8 => xdg_wm_base,
      9 => xdg_surface
    })
    connection.instance_variable_set(:@globals, {})

    pong_serials = []
    configure_serials = []
    flush_count = 0

    xdg_wm_base.define_singleton_method(:pong) { |serial| pong_serials << serial }
    xdg_surface.define_singleton_method(:ack_configure) { |serial| configure_serials << serial }
    connection.define_singleton_method(:flush) { flush_count += 1 }

    registry_payload = [5, 7].pack("VV") + "wl_shm\x00" + "\x00" + [1].pack("V")

    connection.send(:handle_event, 7, 0, registry_payload)
    connection.send(:handle_event, 8, 0, [99].pack("V"))
    connection.send(:handle_event, 9, 0, [101].pack("V"))

    assert_equal({ "wl_shm" => { name: 5, version: 1 } }, connection.instance_variable_get(:@globals))
    assert_equal [99], pong_serials
    assert_equal [101], configure_serials
    assert_equal 2, flush_count
    assert_true xdg_surface.configured?
  end

  test "registry global_remove discards the advertised global" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    registry = RBGL::GUI::Wayland::Registry.allocate
    connection.instance_variable_set(:@objects, { 7 => registry })
    connection.instance_variable_set(
      :@globals,
      { "wl_seat" => { name: 5, version: 5 }, "wl_shm" => { name: 6, version: 1 } }
    )

    connection.send(:handle_event, 7, 1, [5].pack("V"))

    assert_equal({ "wl_shm" => { name: 6, version: 1 } }, connection.globals)
  end

  test "handle_event queues toplevel configure events" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    toplevel = RBGL::GUI::Wayland::XdgToplevel.allocate

    connection.instance_variable_set(:@objects, { 12 => toplevel })
    connection.instance_variable_set(:@pending_events, [])

    connection.send(:handle_event, 12, 0, [640, 480].pack("l<l<"))

    assert_equal [
      { type: :xdg_toplevel_configure, object_id: 12, width: 640, height: 480 }
    ], connection.instance_variable_get(:@pending_events)
  end

  test "handle_event releases wl_buffer objects" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    buffer = RBGL::GUI::Wayland::WlBuffer.new(Object.new, 14)
    buffer.mark_in_use

    connection.instance_variable_set(:@objects, { 14 => buffer })

    connection.send(:handle_event, 14, 0, +"")

    assert_true buffer.available?
  end

  test "handle_event converts keyboard focus and key events" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    keyboard = RBGL::GUI::Wayland::Keyboard.new(connection, 21)
    connection.instance_variable_set(:@objects, { 21 => keyboard })
    connection.instance_variable_set(:@pending_events, [])

    connection.send(:handle_event, 21, 1, [9, 10, 0].pack("V3"))
    connection.send(:handle_event, 21, 3, [9, 100, 1, 1].pack("V4"))
    connection.send(:handle_event, 21, 3, [10, 110, 1, 0].pack("V4"))

    assert_equal [
      { type: :key_press, surface_id: 10, key: :escape, keycode: 1 },
      { type: :key_release, surface_id: 10, key: :escape, keycode: 1 }
    ], connection.instance_variable_get(:@pending_events)
  end

  test "handle_event tracks keyboard modifiers" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    keyboard = RBGL::GUI::Wayland::Keyboard.new(connection, 21)
    connection.instance_variable_set(:@objects, { 21 => keyboard })
    connection.instance_variable_set(:@pending_events, [])

    connection.send(:handle_event, 21, 1, [9, 10, 0].pack("V3"))
    connection.send(:handle_event, 21, 4, [9, 1, 2, 4, 3].pack("V5"))
    connection.send(:handle_event, 21, 3, [9, 100, 30, 1].pack("V4"))

    assert_equal({ depressed: 1, latched: 2, locked: 4, group: 3 }, keyboard.modifiers)
    assert_equal keyboard.modifiers,
                 connection.instance_variable_get(:@pending_events).first[:modifiers]
  end

  test "handle_event converts pointer motion and button events" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    pointer = RBGL::GUI::Wayland::Pointer.new(connection, 22)
    connection.instance_variable_set(:@objects, { 22 => pointer })
    connection.instance_variable_set(:@pending_events, [])

    connection.send(:handle_event, 22, 0, [9, 10, 1280, 2560].pack("VVl<l<"))
    connection.send(:handle_event, 22, 2, [100, 1536, 2816].pack("Vl<l<"))
    connection.send(:handle_event, 22, 3, [9, 100, 0x110, 1].pack("V4"))

    assert_equal [
      { type: :pointer_motion, surface_id: 10, x: 5.0, y: 10.0 },
      { type: :pointer_motion, surface_id: 10, x: 6.0, y: 11.0 },
      { type: :pointer_button_press, surface_id: 10, button: 1, x: 6.0, y: 11.0 }
    ], connection.instance_variable_get(:@pending_events)
  end

  test "handle_event converts pointer axis events" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    pointer = RBGL::GUI::Wayland::Pointer.new(connection, 22)
    pointer.focus(10)
    pointer.move(6.0, 11.0)
    connection.instance_variable_set(:@objects, { 22 => pointer })
    connection.instance_variable_set(:@pending_events, [])

    connection.send(:handle_event, 22, 4, [100, 0, -384].pack("VVl<"))

    assert_equal [
      { type: :pointer_axis, surface_id: 10, axis: :vertical, value: -1.5, x: 6.0, y: 11.0 }
    ], connection.instance_variable_get(:@pending_events)
  end

  test "input mapper preserves unknown codes while normalizing common input" do
    assert_equal :a, RBGL::GUI::Wayland::InputMapper.key(30)
    assert_equal 999, RBGL::GUI::Wayland::InputMapper.key(999)
    assert_equal 3, RBGL::GUI::Wayland::InputMapper.button(0x111)
  end

  test "pack_args encodes typed wayland arguments" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    args = [
      RBGL::GUI::Wayland::Arguments.uint(1),
      RBGL::GUI::Wayland::Arguments.int(-2),
      RBGL::GUI::Wayland::Arguments.fixed(1.5),
      RBGL::GUI::Wayland::Arguments.string("wl"),
      RBGL::GUI::Wayland::Arguments.object(9),
      RBGL::GUI::Wayland::Arguments.new_id(10)
    ]

    packed = connection.send(:pack_args, args)

    expected = [
      [1].pack("V"),
      [-2].pack("l<"),
      [384].pack("l<"),
      [3].pack("V") + "wl\x00\x00",
      [9].pack("V"),
      [10].pack("V")
    ].join

    assert_equal expected, packed
  end

  test "pack_args rejects untyped protocol arguments" do
    connection = RBGL::GUI::Wayland::Connection.allocate

    assert_raise(ArgumentError) { connection.send(:pack_args, [1]) }
  end

  test "send_request_with_fd sends an IO descriptor" do
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    file = Tempfile.new("rbgl-wayland-rights")
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@socket, sender)

    connection.send_request_with_fd(
      4,
      0,
      RBGL::GUI::Wayland::Arguments.new_id(5),
      RBGL::GUI::Wayland::Arguments.int(16),
      file
    )

    message = receiver.recvmsg(scm_rights: true)
    received_files = message.drop(3).flat_map(&:unix_rights)

    assert_equal 16, message.first.bytesize
    assert_equal 1, received_files.size
  ensure
    received_files&.compact&.each(&:close)
    file&.close!
    sender&.close
    receiver&.close
  end

  test "send_request_with_fd rejects integer descriptors" do
    connection = RBGL::GUI::Wayland::Connection.allocate

    assert_raise(ArgumentError) do
      connection.send_request_with_fd(4, 0, 9)
    end
  end

  test "pump_events buffers partial protocol messages" do
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    connection = RBGL::GUI::Wayland::Connection.allocate
    toplevel = RBGL::GUI::Wayland::XdgToplevel.allocate
    payload = [320, 200].pack("l<l<")
    message = [12, ((payload.bytesize + 8) << 16)].pack("VV") + payload

    connection.instance_variable_set(:@socket, receiver)
    connection.instance_variable_set(:@objects, { 12 => toplevel })
    connection.instance_variable_set(:@pending_events, [])
    connection.instance_variable_set(:@read_buffer, String.new(encoding: Encoding::BINARY))

    sender.write(message.byteslice(0, 5))
    connection.pump_events(timeout: 0.01)
    assert_empty connection.dispatch_pending

    sender.write(message.byteslice(5..))
    connection.pump_events(timeout: 0.01)

    assert_equal [
      { type: :xdg_toplevel_configure, object_id: 12, width: 320, height: 200 }
    ], connection.dispatch_pending
  ensure
    sender&.close
    receiver&.close
  end

  test "receive_message preserves wait state for basic nonblocking sockets" do
    socket = Object.new
    socket.define_singleton_method(:read_nonblock) { |_length, exception:| exception ? nil : :wait_readable }
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@socket, socket)

    assert_equal :wait_readable, connection.send(:receive_message)
  end

  test "socket EOF raises backend unavailable" do
    reader, writer = UNIXSocket.pair
    writer.close
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@socket, reader)
    connection.instance_variable_set(:@read_buffer, String.new(encoding: Encoding::BINARY))
    connection.instance_variable_set(:@received_fds, [])

    assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(:read_from_socket, 0)
    end
  ensure
    reader&.close unless reader&.closed?
    writer&.close unless writer&.closed?
  end

  test "pump_events receives the keyboard keymap file descriptor" do
    sender, receiver = Socket.pair(:UNIX, :STREAM, 0)
    keymap_file = Tempfile.new("rbgl-wayland-keymap")
    keymap = "xkb_keymap { };\x00"
    keymap_file.binmode
    keymap_file.write(keymap)
    keymap_file.rewind
    connection = RBGL::GUI::Wayland::Connection.allocate
    keyboard = RBGL::GUI::Wayland::Keyboard.new(connection, 21)
    payload = [1, keymap.bytesize].pack("V2")
    message = [21, ((payload.bytesize + 8) << 16)].pack("VV") + payload

    connection.instance_variable_set(:@socket, receiver)
    connection.instance_variable_set(:@objects, { 21 => keyboard })
    connection.instance_variable_set(:@pending_events, [])
    connection.instance_variable_set(:@received_fds, [])
    connection.instance_variable_set(:@read_buffer, String.new(encoding: Encoding::BINARY))

    sender.sendmsg(message, 0, nil, Socket::AncillaryData.unix_rights(keymap_file.to_io))
    connection.pump_events(timeout: 0.01)

    assert_equal :xkb_v1, keyboard.keymap_format
    assert_equal "xkb_keymap { };", keyboard.keymap
    assert_empty connection.instance_variable_get(:@received_fds)
  ensure
    keymap_file&.close!
    sender&.close
    receiver&.close
  end

  test "display delete_id removes released protocol objects" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    display = RBGL::GUI::Wayland::Display.new(connection)
    released = Object.new
    connection.instance_variable_set(:@objects, { 1 => display, 42 => released })

    connection.send(:handle_event, 1, 1, [42].pack("V"))

    assert_nil connection.object_for(42)
  end

  test "display errors raise backend unavailable with protocol context" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    display = RBGL::GUI::Wayland::Display.new(connection)
    message = "invalid surface"
    payload = [7, 3, message.bytesize + 1].pack("VVV") + message + "\x00"
    connection.instance_variable_set(:@objects, { 1 => display })

    error = assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(:handle_event, 1, 0, payload)
    end

    assert_includes error.message, "object 7"
    assert_includes error.message, message
  end

  test "close releases the Wayland socket once" do
    socket = Object.new
    closed = false
    socket.define_singleton_method(:closed?) { closed }
    socket.define_singleton_method(:close) { closed = true }
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@socket, socket)
    connection.instance_variable_set(:@closed, false)

    2.times { connection.close }

    assert_true connection.closed?
  end

  test "resolve_socket_path uses injected env values" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@env, {
      "WAYLAND_DISPLAY" => "wayland-test",
      "XDG_RUNTIME_DIR" => "/tmp/rbgl-wayland"
    })

    path = connection.send(:resolve_socket_path)

    assert_equal "/tmp/rbgl-wayland/wayland-test", path
  end

  test "resolve_socket_path keeps absolute socket paths" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    connection.instance_variable_set(:@env, {})

    path = connection.send(:resolve_socket_path, "/tmp/custom-wayland.sock")

    assert_equal "/tmp/custom-wayland.sock", path
  end

  test "roundtrip raises when callback is not completed before timeout" do
    connection = RBGL::GUI::Wayland::Connection.allocate
    callback = Object.new
    callback.define_singleton_method(:id) { 10 }
    callback.define_singleton_method(:done?) { false }
    display = Object.new
    display.define_singleton_method(:sync) { callback }
    pump_calls = 0
    times = [0.0, 0.0, 0.03, 0.03]

    connection.instance_variable_set(:@display, display)
    connection.instance_variable_set(:@objects, {})
    connection.instance_variable_set(:@roundtrip_timeout, 0.02)
    connection.define_singleton_method(:flush) {}
    connection.define_singleton_method(:pump_events) { |timeout:| pump_calls += 1; timeout }
    connection.define_singleton_method(:monotonic_time) { times.shift || 0.03 }

    assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.roundtrip
    end

    assert_nil connection.instance_variable_get(:@objects)[10]
    assert_equal 1, pump_calls
  end
end

class WaylandBackendTest < Test::Unit::TestCase
  FakeObject = Struct.new(:id)

  class FakeConnection
    def initialize(events)
      @events = events
    end

    def dispatch_pending
      @events
    end
  end

  test "poll_events converts wayland close and resize events" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    toplevel = FakeObject.new(33)
    backend.instance_variable_set(
      :@window,
      {
        toplevel: toplevel,
        width: 100,
        height: 80,
        should_close: false
      }
    )
    backend.instance_variable_set(
      :@connection,
      FakeConnection.new([
        { type: :xdg_toplevel_configure, object_id: 33, width: 320, height: 200 },
        { type: :xdg_toplevel_close, object_id: 33 }
      ])
    )

    events = backend.poll_events

    assert_equal [:resize, :close], events.map(&:type)
    assert_true backend.should_close?
  end

  test "configure leaves buffer dimensions unchanged until resize" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    toplevel = FakeObject.new(33)
    window = { toplevel: toplevel, width: 100, height: 80, should_close: false }
    backend.instance_variable_set(:@window, window)

    event = backend.send(:convert_event, {
      type: :xdg_toplevel_configure, object_id: 33, width: 320, height: 200
    })

    assert_equal [320, 200], [event.width, event.height]
    assert_equal [100, 80], [window[:width], window[:height]]
  end

  test "poll_events converts keyboard and pointer events for the focused surface" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    surface = FakeObject.new(10)
    toplevel = FakeObject.new(33)
    backend.instance_variable_set(
      :@window,
      {
        surface: surface,
        toplevel: toplevel,
        should_close: false
      }
    )
    backend.instance_variable_set(
      :@connection,
      FakeConnection.new([
        { type: :key_press, surface_id: 10, key: :escape, keycode: 1 },
        { type: :pointer_motion, surface_id: 10, x: 12.5, y: 20.0 },
        { type: :pointer_button_press, surface_id: 10, button: 1, x: 12.5, y: 20.0 },
        { type: :pointer_axis, surface_id: 10, axis: :vertical, value: -1.0, x: 12.5, y: 20.0 }
      ])
    )

    events = backend.poll_events

    assert_equal %i[key_press mouse_move mouse_press mouse_scroll], events.map(&:type)
    assert_equal :escape, events[0].key
    assert_equal 12.5, events[1].x
    assert_equal 1, events[2].button
    assert_equal(-1.0, events[3].value)
  end

  test "close destroys and clears wayland window resources" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    destroyed = []
    backend.instance_variable_set(
      :@window,
      {
        toplevel: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { destroyed << :toplevel } },
        xdg_surface: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { destroyed << :xdg_surface } },
        surface: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { destroyed << :surface } },
        shm_buffer: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { |force: false| destroyed << [:shm_buffer, force] } },
        should_close: false
      }
    )
    connection = Object.new
    connection.define_singleton_method(:flush) { destroyed << :flush }
    connection.define_singleton_method(:close) { destroyed << :connection }
    backend.instance_variable_set(:@connection, connection)

    backend.close

    assert_equal [
      :toplevel,
      :xdg_surface,
      :surface,
      [:shm_buffer, true],
      :flush,
      :connection
    ], destroyed
    assert_nil backend.instance_variable_get(:@window)
  end

  test "setup commits an empty surface and waits for configure before allocating buffers" do
    calls = []
    surface = Object.new
    surface.define_singleton_method(:id) { 10 }
    surface.define_singleton_method(:commit) { calls << :empty_commit }
    xdg_surface = Object.new
    configured = false
    xdg_surface.define_singleton_method(:get_toplevel) { @toplevel }
    xdg_surface.define_singleton_method(:configured?) { configured }
    toplevel = Object.new
    toplevel.define_singleton_method(:set_title) { |_title| calls << :title }
    xdg_surface.instance_variable_set(:@toplevel, toplevel)
    compositor = Object.new
    compositor.define_singleton_method(:create_surface) { surface }
    wm_base = Object.new
    wm_base.define_singleton_method(:get_xdg_surface) { |_surface| xdg_surface }
    connection = Object.new
    connection.define_singleton_method(:compositor) { compositor }
    connection.define_singleton_method(:xdg_wm_base) { wm_base }
    connection.define_singleton_method(:flush) { calls << :flush }
    connection.define_singleton_method(:wait_until) do |&block|
      calls << :wait_for_configure
      configured = true
      block.call
    end
    buffer = Object.new

    backend = RBGL::GUI::Wayland::Backend.allocate
    backend.instance_variable_set(:@connection, connection)
    backend.instance_variable_set(:@window, nil)
    backend.define_singleton_method(:create_shm_buffers) do |_width, _height|
      calls << :create_buffers
      [buffer]
    end

    backend.send(:setup_window, 100, 80, "Test")

    assert_equal [:title, :empty_commit, :flush, :wait_for_configure, :create_buffers], calls
    assert_equal buffer, backend.instance_variable_get(:@window)[:shm_buffer]
  end

  test "resize recreates shm buffer for the current window" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    old_buffer_destroyed = false
    old_buffer = Object.new
    new_buffer = Object.new
    old_buffer.define_singleton_method(:destroy) { old_buffer_destroyed = true }
    old_buffer.define_singleton_method(:available?) { true }

    backend.instance_variable_set(
      :@window,
      {
        buffers: [old_buffer],
        shm_buffer: old_buffer,
        width: 100,
        height: 80
      }
    )

    created = []
    backend.define_singleton_method(:create_shm_buffers) do |width, height, count = 2|
      created << [width, height]
      Array.new(count, new_buffer)
    end

    backend.resize(320, 200)

    assert_equal [[320, 200]], created
    assert_true old_buffer_destroyed
    assert_equal [new_buffer, new_buffer], backend.instance_variable_get(:@window)[:buffers]
    assert_equal new_buffer, backend.instance_variable_get(:@window)[:shm_buffer]
    assert_equal 320, backend.width
    assert_equal 200, backend.height
  end

  test "present uses the next available shm buffer" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    framebuffer = RBGL::Engine::Framebuffer.new(2, 2)
    written = []
    attached = []
    committed = 0

    busy_buffer = Object.new
    busy_buffer.define_singleton_method(:available?) { false }
    free_buffer = Object.new
    free_buffer.define_singleton_method(:available?) { true }
    free_buffer.define_singleton_method(:write) { |data| written << data }
    free_buffer.define_singleton_method(:mark_in_use) { }

    surface = Object.new
    surface.define_singleton_method(:damage) { |_x, _y, _w, _h| }
    surface.define_singleton_method(:attach) { |buffer, _x, _y| attached << buffer }
    surface.define_singleton_method(:commit) { committed += 1 }

    connection = Object.new
    connection.define_singleton_method(:flush) { }

    backend.instance_variable_set(:@connection, connection)
    backend.instance_variable_set(
      :@window,
      {
        surface: surface,
        buffers: [busy_buffer, free_buffer],
        shm_buffer: busy_buffer
      }
    )

    backend.present(framebuffer)

    assert_equal 1, written.size
    assert_equal [free_buffer], attached
    assert_equal 1, committed
    assert_equal free_buffer, backend.instance_variable_get(:@window)[:shm_buffer]
  end

  test "set_pixels writes raw RGBA bytes directly in Wayland byte order" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    written = nil
    buffer = Object.new
    buffer.define_singleton_method(:available?) { true }
    buffer.define_singleton_method(:write) { |data| written = data }
    buffer.define_singleton_method(:mark_in_use) {}
    surface = Object.new
    surface.define_singleton_method(:damage) { |*_args| }
    surface.define_singleton_method(:attach) { |*_args| }
    surface.define_singleton_method(:commit) {}
    connection = Object.new
    connection.define_singleton_method(:flush) {}
    backend.instance_variable_set(:@connection, connection)
    backend.instance_variable_set(
      :@window,
      { surface: surface, buffers: [buffer], shm_buffer: buffer, should_close: false }
    )

    backend.set_pixels("\xFF\x80\x00\x40", 1, 1)

    assert_equal [0, 128, 255, 64], written.bytes
  end

  test "present waits for a released shm buffer instead of dropping the frame" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    framebuffer = RBGL::Engine::Framebuffer.new(2, 2)
    written = []
    attached = []
    pump_calls = 0
    available = false

    buffer = Object.new
    buffer.define_singleton_method(:available?) { available }
    buffer.define_singleton_method(:write) { |data| written << data }
    buffer.define_singleton_method(:mark_in_use) { available = false }

    surface = Object.new
    surface.define_singleton_method(:damage) { |_x, _y, _w, _h| }
    surface.define_singleton_method(:attach) { |current, _x, _y| attached << current }
    surface.define_singleton_method(:commit) { }

    connection = Object.new
    connection.define_singleton_method(:flush) { }
    connection.define_singleton_method(:pump_events) do |timeout:|
      pump_calls += 1
      available = true if timeout.positive?
    end

    backend.instance_variable_set(:@connection, connection)
    backend.instance_variable_set(
      :@window,
      {
        surface: surface,
        buffers: [buffer],
        shm_buffer: buffer
      }
    )

    result = backend.present(framebuffer)

    assert_equal 1, pump_calls
    assert_equal 1, written.size
    assert_equal [buffer], attached
    assert_true result
  end

  test "present aborts when no shm buffer becomes available before timeout" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    framebuffer = RBGL::Engine::Framebuffer.new(2, 2)
    written = []
    attached = []
    pump_calls = 0
    times = [0.0, 0.1, 0.3]

    buffer = Object.new
    buffer.define_singleton_method(:available?) { false }
    buffer.define_singleton_method(:write) { |data| written << data }
    buffer.define_singleton_method(:mark_in_use) { }

    surface = Object.new
    surface.define_singleton_method(:damage) { |_x, _y, _w, _h| }
    surface.define_singleton_method(:attach) { |current, _x, _y| attached << current }
    surface.define_singleton_method(:commit) { }

    connection = Object.new
    connection.define_singleton_method(:flush) { }
    connection.define_singleton_method(:pump_events) do |timeout:|
      pump_calls += 1
      timeout
    end

    backend.instance_variable_set(:@connection, connection)
    backend.instance_variable_set(
      :@window,
      {
        surface: surface,
        buffers: [buffer],
        shm_buffer: buffer,
        should_close: false
      }
    )
    backend.define_singleton_method(:monotonic_time) { times.shift || times.last || 0.3 }

    result = backend.present(framebuffer)

    assert_equal 1, pump_calls
    assert_empty written
    assert_empty attached
    assert_false result
  end

  test "create_shm_buffer wraps the file, pool, and wl_buffer" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    tempfile = Tempfile.new("rbgl-wayland-test")
    tempfile.truncate(16)

    pool = Object.new
    wl_buffer = Object.new
    wl_buffer.define_singleton_method(:on_release) { |&block| block }
    wl_buffer.define_singleton_method(:busy?) { false }
    wl_buffer.define_singleton_method(:destroy) { }
    format = nil
    pool.define_singleton_method(:create_buffer) do |_offset, _width, _height, _stride, received_format|
      format = received_format
      wl_buffer
    end
    shm = Object.new
    received_file = nil
    shm.define_singleton_method(:create_pool) { |file, _size| received_file = file; pool }
    connection = Object.new
    connection.define_singleton_method(:shm) { shm }

    backend.instance_variable_set(:@connection, connection)
    backend.define_singleton_method(:create_anonymous_file) { |_size| tempfile }

    shm_buffer = backend.send(:create_shm_buffer, 2, 2)

    assert_equal wl_buffer, shm_buffer.wl_buffer
    assert_same tempfile, received_file
    assert_equal :xrgb8888, format
  ensure
    tempfile.close!
  end

  test "shm_buffer writes bytes and destroys owned resources" do
    tempfile = Tempfile.new("rbgl-shm-buffer")
    wl_buffer_destroyed = false
    pool_destroyed = false
    release_callback = nil
    wl_buffer = Object.new
    wl_buffer.define_singleton_method(:id) { 55 }
    wl_buffer.define_singleton_method(:on_release) { |&block| release_callback = block }
    wl_buffer.define_singleton_method(:busy?) { false }
    pool = Object.new
    wl_buffer.define_singleton_method(:destroy) { wl_buffer_destroyed = true }
    pool.define_singleton_method(:destroy) { pool_destroyed = true }

    shm_buffer = RBGL::GUI::Wayland::ShmBuffer.new(tempfile, pool, wl_buffer)
    shm_buffer.write("ABCD")
    tempfile.rewind

    assert_equal "ABCD", tempfile.read(4)
    assert_equal wl_buffer.id, shm_buffer.id

    shm_buffer.destroy

    assert_true wl_buffer_destroyed
    assert_true pool_destroyed
    assert_true tempfile.closed?
    assert_not_nil release_callback
  end

  test "shm_buffer defers resource cleanup until release when busy" do
    tempfile = Tempfile.new("rbgl-shm-buffer-busy")
    release_callback = nil
    busy = true
    destroyed = false
    pool_destroyed = false
    wl_buffer = Object.new
    wl_buffer.define_singleton_method(:id) { 56 }
    wl_buffer.define_singleton_method(:on_release) { |&block| release_callback = block }
    wl_buffer.define_singleton_method(:busy?) { busy }
    wl_buffer.define_singleton_method(:destroy) { destroyed = true }
    pool = Object.new
    pool.define_singleton_method(:destroy) { pool_destroyed = true }

    shm_buffer = RBGL::GUI::Wayland::ShmBuffer.new(tempfile, pool, wl_buffer)
    shm_buffer.destroy

    assert_true destroyed
    assert_false pool_destroyed
    busy = false
    release_callback.call

    assert_true pool_destroyed
    assert_true tempfile.closed?
  end
end
