# frozen_string_literal: true

require_relative "../../test_helper"
require "rbgl/gui/wayland/backend"
require "rbgl/gui/wayland/connection"
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
      @requests << [object_id, opcode, args]
    end

    def send_request_with_fd(object_id, opcode, *args, fd)
      @fd_requests << [object_id, opcode, args, fd]
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
      [1, 0, [10]],
      [1, 1, [11]]
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
    pool = shm.create_pool(9, 64)
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
    assert_equal [4, 0, [23, 64], 9], connection.fd_requests.first
    assert_equal [
      [2, 0, [1, "wl_compositor", 4, 21]],
      [3, 0, [22]],
      [5, 2, [24, 22]],
      [24, 1, [25]],
      [23, 0, [26, 0, 4, 4, 16, 0]],
      [22, 1, [26, 0, 0]],
      [22, 2, [1, 2, 3, 4]],
      [22, 6, []],
      [22, 0, []],
      [5, 3, [77]],
      [24, 4, [88]],
      [24, 0, []],
      [25, 2, ["RBGL"]],
      [25, 0, []],
      [23, 1, []]
    ], connection.requests
  end

  test "callback tracks done state" do
    callback = RBGL::GUI::Wayland::Callback.new(Object.new, 1)

    assert_false callback.done?

    callback.handle_done

    assert_true callback.done?
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
    xdg_surface = RBGL::GUI::Wayland::XdgSurface.allocate

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
    backend.instance_variable_set(:@handle, 10)
    backend.instance_variable_set(
      :@windows,
      {
        10 => {
          toplevel: toplevel,
          width: 100,
          height: 80,
          should_close: false
        }
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

  test "close destroys wayland window resources and clears handle" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    destroyed = []
    backend.instance_variable_set(:@handle, 10)
    backend.instance_variable_set(
      :@windows,
      {
        10 => {
          toplevel: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { destroyed << :toplevel } },
          xdg_surface: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { destroyed << :xdg_surface } },
          surface: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { destroyed << :surface } },
          shm_buffer: Object.new.tap { |obj| obj.define_singleton_method(:destroy) { destroyed << :shm_buffer } },
          should_close: false
        }
      }
    )

    backend.close

    assert_equal [:toplevel, :xdg_surface, :surface, :shm_buffer], destroyed
    assert_nil backend.instance_variable_get(:@handle)
  end

  test "create_shm_buffer wraps the file, pool, and wl_buffer" do
    backend = RBGL::GUI::Wayland::Backend.allocate
    tempfile = Tempfile.new("rbgl-wayland-test")
    tempfile.truncate(16)

    pool = Object.new
    wl_buffer = Object.new
    pool.define_singleton_method(:create_buffer) { |_offset, _width, _height, _stride, _format| wl_buffer }
    shm = Object.new
    shm.define_singleton_method(:create_pool) { |_fd, _size| pool }
    connection = Object.new
    connection.define_singleton_method(:shm) { shm }

    backend.instance_variable_set(:@connection, connection)
    backend.define_singleton_method(:create_anonymous_file) { |_size| tempfile }

    shm_buffer = backend.send(:create_shm_buffer, 2, 2)

    assert_equal wl_buffer, shm_buffer.wl_buffer
  ensure
    tempfile.close!
  end

  test "shm_buffer writes bytes and destroys owned resources" do
    tempfile = Tempfile.new("rbgl-shm-buffer")
    wl_buffer_destroyed = false
    pool_destroyed = false
    wl_buffer = Struct.new(:id).new(55)
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
  end
end
