# frozen_string_literal: true

require_relative "../../test_helper"
require "rbgl/gui/x11/backend"
require "rbgl/gui/x11/connection"
require "tempfile"

class X11ConnectionTest < Test::Unit::TestCase
  class FakeSocket
    attr_reader :writes, :flush_count

    def initialize(*reads)
      @reads = reads.flatten
      @writes = []
      @flush_count = 0
      @closed = false
    end

    def write(data)
      @writes << data
      data.bytesize
    end

    def flush
      @flush_count += 1
    end

    def read(_length)
      @reads.shift
    end

    def wait_readable(_timeout = nil)
      !@reads.empty?
    end

    def read_nonblock(length, exception: false)
      return :wait_readable if @reads.empty? && !exception

      chunk = @reads.shift
      return nil if chunk.nil?
      return chunk if chunk.bytesize <= length

      @reads.unshift(chunk.byteslice(length..))
      chunk.byteslice(0, length)
    end

    def closed?
      @closed
    end

    def close
      @closed = true
    end
  end

  test "change_property supports 32-bit atom payloads" do
    connection = RBGL::GUI::X11::Connection.allocate
    sent = nil

    connection.define_singleton_method(:atom) do |name|
      {
        wm_protocols: 68,
        atom: 4
      }.fetch(name)
    end
    connection.define_singleton_method(:send_request) do |opcode, data, extra = 0|
      sent = [opcode, data, extra]
      0
    end

    connection.change_property(10, :wm_protocols, :atom, [77], format: 32)

    opcode, request, extra = sent
    window, property_atom, type_atom, format, value_count = request[0, 17].unpack("VVVCV")

    assert_equal 18, opcode
    assert_equal 0, extra
    assert_equal 10, window
    assert_equal 68, property_atom
    assert_equal 4, type_atom
    assert_equal 32, format
    assert_equal 1, value_count
    assert_equal [77].pack("V"), request[20, 4]
  end

  test "enable_wm_delete_window writes wm protocol atom" do
    connection = RBGL::GUI::X11::Connection.allocate
    calls = []

    connection.define_singleton_method(:wm_delete_window_atom) { 77 }
    connection.define_singleton_method(:change_property) do |window, property, type, data, mode: :replace, format: 8|
      calls << [window, property, type, data, mode, format]
    end

    connection.enable_wm_delete_window(15)

    assert_equal [[15, :wm_protocols, :atom, [77], :replace, 32]], calls
  end

  test "generate_id increments from resource base" do
    connection = build_connection
    connection.instance_variable_set(:@resource_id_base, 0x1000)
    connection.instance_variable_set(:@resource_id_mask, 0x0FFF)
    connection.instance_variable_set(:@resource_id_counter, 0)

    assert_equal 0x1000, connection.generate_id
    assert_equal 0x1001, connection.generate_id
  end

  test "generate_id raises when resource id space is exhausted" do
    connection = build_connection
    connection.instance_variable_set(:@resource_id_base, 0x1000)
    connection.instance_variable_set(:@resource_id_mask, 0x0001)
    connection.instance_variable_set(:@resource_id_counter, 0x0002)

    assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.generate_id
    end
  end

  test "flush delegates to socket" do
    socket = FakeSocket.new
    connection = build_connection(socket: socket)

    connection.flush

    assert_equal 1, socket.flush_count
  end

  test "pending returns whether the socket is readable" do
    reader, writer = IO.pipe
    connection = build_connection(socket: reader)

    writer.write("x")
    writer.flush
    assert_equal 1, connection.pending

    connection.send(:transport).read_exact(1)
    assert_equal 0, connection.pending
  ensure
    reader&.close unless reader&.closed?
    writer&.close unless writer&.closed?
  end

  test "create_window encodes window attributes and event masks" do
    connection = build_connection
    sent = nil
    connection.define_singleton_method(:send_request) do |opcode, data, extra = 0|
      sent = [opcode, data, extra]
      0
    end

    connection.create_window(
      depth: 24,
      wid: 10,
      parent: 1,
      x: 2, y: 3,
      width: 320, height: 240,
      border_width: 0,
      window_class: :input_output,
      visual: 99,
      value_mask: [:back_pixel, :event_mask],
      values: {
        back_pixel: 0,
        event_mask: [:exposure, :key_press, :key_release, :button_press,
                     :button_release, :pointer_motion, :structure_notify]
      }
    )

    opcode, data, extra = sent
    assert_equal 1, opcode
    assert_equal 24, extra
    assert_equal 36, data.bytesize
    assert_equal [2, 3], data.byteslice(8, 4).unpack("s<s<")
  end

  test "create_window rejects unknown event masks" do
    connection = build_connection

    assert_raise(KeyError) do
      connection.create_window(
        depth: 24,
        wid: 10,
        parent: 1,
        x: 0,
        y: 0,
        width: 1,
        height: 1,
        border_width: 0,
        window_class: :input_output,
        visual: 99,
        value_mask: [:event_mask],
        values: { event_mask: [:unknown] }
      )
    end
  end

  test "map_window destroy_window and create_gc delegate through send_request" do
    connection = build_connection
    sent = []
    connection.define_singleton_method(:send_request) do |opcode, data, extra = 0|
      sent << [opcode, data, extra]
    end

    connection.map_window(10)
    connection.destroy_window(11)
    connection.create_gc(12, 13, foreground: 1, background: 2)

    assert_equal 3, sent.size
    assert_equal [8, [10].pack("V"), 0], sent[0]
    assert_equal [4, [11].pack("V"), 0], sent[1]
    assert_equal 55, sent[2][0]
  end

  test "put_image forwards bulk image data with each format selector" do
    connection = build_connection
    sent = []
    connection.define_singleton_method(:send_request_with_data) do |opcode, extra, header_data, bulk_data|
      sent << [opcode, extra, header_data, bulk_data]
    end

    { bitmap: 0, xy_pixmap: 1, z_pixmap: 2 }.each do |format, expected_extra|
      connection.put_image(
        format: format,
        drawable: 1,
        gc: 2,
        width: 3,
        height: 1,
        dst_x: 5,
        dst_y: 6,
        depth: 24,
        data: "pixels",
        bytes_per_line: 6
      )

      opcode, extra, header_data, bulk_data = sent.last
      assert_equal 72, opcode
      assert_equal expected_extra, extra
      assert_equal "pixels", bulk_data
      assert_equal 20, header_data.bytesize
    end


    assert_raise(KeyError) do
      connection.put_image(
        format: :other,
        drawable: 1,
        gc: 2,
        width: 1,
        height: 1,
        dst_x: 0,
        dst_y: 0,
        depth: 24,
        data: "xxxx",
        bytes_per_line: 4
      )
    end
  end

  test "put_image splits image rows to respect the server request limit" do
    connection = build_connection
    connection.instance_variable_set(:@maximum_request_length, 10)
    sent = []
    connection.define_singleton_method(:send_request_with_data) do |_opcode, _extra, header, data|
      sent << [header, data]
    end

    connection.put_image(
      format: :z_pixmap,
      drawable: 1,
      gc: 2,
      width: 2,
      height: 5,
      dst_x: 3,
      dst_y: 4,
      depth: 24,
      data: "x" * 40,
      bytes_per_line: 8
    )

    assert_equal 3, sent.size
    assert_equal [2, 2, 3, 4], sent[0][0].byteslice(8, 8).unpack("vvs<s<")
    assert_equal [2, 2, 3, 6], sent[1][0].byteslice(8, 8).unpack("vvs<s<")
    assert_equal [2, 1, 3, 8], sent[2][0].byteslice(8, 8).unpack("vvs<s<")
    assert_equal [16, 16, 8], sent.map { |_header, data| data.bytesize }
  end

  test "put_image rejects rows larger than the server request limit" do
    connection = build_connection
    connection.instance_variable_set(:@maximum_request_length, 10)

    assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.put_image(
        format: :z_pixmap,
        drawable: 1,
        gc: 2,
        width: 5,
        height: 1,
        dst_x: 0,
        dst_y: 0,
        depth: 24,
        data: "x" * 20,
        bytes_per_line: 20
      )
    end
  end

  test "pack_property_data supports 8 16 and 32 bit values" do
    connection = build_connection

    bytes8, count8 = connection.send(:pack_property_data, "abc", 8)
    bytes16, count16 = connection.send(:pack_property_data, [1, 2], 16)
    bytes32, count32 = connection.send(:pack_property_data, [3, 4], 32)

    assert_equal "abc", bytes8
    assert_equal 3, count8
    assert_equal [1, 2].pack("v*"), bytes16
    assert_equal 2, count16
    assert_equal [3, 4].pack("V*"), bytes32
    assert_equal 2, count32

    assert_raise(ArgumentError) do
      connection.send(:pack_property_data, [1], 64)
    end
  end

  test "intern_atom reads atom id from reply" do
    reply = "\x01" + ("\x00" * 7) + [77].pack("V") + ("\x00" * 20)
    socket = FakeSocket.new(reply)
    connection = build_connection(socket: socket)
    sent = nil
    connection.define_singleton_method(:send_request) do |opcode, data, extra = 0|
      sent = [opcode, data, extra]
      0
    end

    atom = connection.intern_atom("WM_PROTOCOLS", only_if_exists: true)

    assert_equal 77, atom
    assert_equal 16, sent[0]
    assert_equal 1, sent[2]
    assert_equal 1, socket.flush_count
  end

  test "next_event returns queued events and reads from socket when needed" do
    connection = build_connection
    connection.instance_variable_set(:@pending_events, [{ type: :queued }])

    assert_equal({ type: :queued }, connection.next_event)

    connection.instance_variable_set(:@pending_events, [])
    payload = "\x00" * 32
    payload.setbyte(0, 12)
    connection.instance_variable_set(:@socket, FakeSocket.new(payload))
    connection.instance_variable_set(:@transport, nil)

    assert_equal({ type: :exposure }, connection.next_event)
  end

  test "parse_display_name accepts unix and tcp formats and rejects invalid names" do
    connection = build_connection

    assert_equal [nil, 0, 0], connection.send(:parse_display_name, ":0")
    assert_equal ["host", 1, 2], connection.send(:parse_display_name, "host:1.2")

    assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(:parse_display_name, "invalid-display")
    end
  end

  test "handshake raises backend unavailable on protocol failure" do
    socket = FakeSocket.new("\x00" * 8)
    connection = build_connection(socket: socket)

    assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(:handshake)
    end

    assert_equal 12, socket.writes.first.bytesize
  end

  test "handshake includes a matching MIT magic cookie" do
    cookie = "0123456789abcdef"
    authority = Tempfile.new("rbgl-xauthority")
    authority.binmode
    authority.write(
      [RBGL::GUI::X11::XAuthority::FAMILY_LOCAL].pack("n") +
      xauthority_field(Socket.gethostname) +
      xauthority_field("0") +
      xauthority_field(RBGL::GUI::X11::XAuthority::AUTH_NAME) +
      xauthority_field(cookie)
    )
    authority.flush
    socket = FakeSocket.new("\x00" * 8)
    connection = build_connection(socket: socket)

    assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(
        :handshake,
        host: nil,
        display_num: 0,
        env: { "XAUTHORITY" => authority.path }
      )
    end

    setup = socket.writes.first
    _order, _padding, major, minor, name_length, data_length, = setup.unpack("CCvvvvv")
    name_offset = 12
    data_offset = name_offset + ((name_length + 3) / 4) * 4
    assert_equal 11, major
    assert_equal 0, minor
    assert_equal RBGL::GUI::X11::XAuthority::AUTH_NAME, setup.byteslice(name_offset, name_length)
    assert_equal cookie, setup.byteslice(data_offset, data_length)
  ensure
    authority&.close!
  end

  test "Xauthority retries entries safely when the file is malformed" do
    authority = Tempfile.new("rbgl-bad-xauthority")
    authority.binmode
    authority.write("\x00")
    authority.flush

    cookie = RBGL::GUI::X11::XAuthority.cookie_for(
      host: nil,
      display_number: 0,
      env: { "XAUTHORITY" => authority.path }
    )

    assert_nil cookie
  ensure
    authority&.close!
  end

  test "parse_server_info extracts root screen metadata" do
    connection = build_connection
    data = build_setup_data

    connection.send(:parse_server_info, data)

    assert_equal 0x1000, connection.resource_id_base
    assert_equal 0x0FFF, connection.resource_id_mask
    assert_equal 10, connection.root
    assert_equal 24, connection.root_depth
    assert_equal 20, connection.root_visual
    assert_equal 65_535, connection.maximum_request_length
    assert_equal 32, connection.bits_per_pixel
    assert_equal 32, connection.scanline_pad
  end

  test "parse_server_info honors the DISPLAY screen number" do
    data = build_setup_data
    second_screen = data.byteslice(40, 72).dup
    second_screen[0, 4] = [11].pack("V")
    second_screen[32, 4] = [21].pack("V")
    second_screen[48, 4] = [21].pack("V")
    data.setbyte(20, 2)
    data << second_screen
    connection = build_connection
    connection.instance_variable_set(:@default_screen, 1)

    connection.send(:parse_server_info, data)

    assert_equal 11, connection.root
    assert_equal 21, connection.root_visual
  end

  test "parse_server_info rejects unavailable DISPLAY screens" do
    connection = build_connection
    connection.instance_variable_set(:@default_screen, 1)

    error = assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(:parse_server_info, build_setup_data)
    end

    assert_includes error.message, "screen 1"
  end

  test "send_request and send_request_with_data write padded packets" do
    socket = FakeSocket.new
    connection = build_connection(socket: socket)

    connection.send(:send_request, 10, "abc", 2)
    connection.send(:send_request_with_data, 11, 3, "head", "body")

    assert_equal 2, socket.writes.size
    assert_equal 8, socket.writes[0].bytesize
    assert_equal 12, socket.writes[1].bytesize
  end

  test "request encoder rejects overflowing core protocol lengths" do
    encoder = RBGL::GUI::X11::RequestEncoder.new

    assert_raise(ArgumentError) do
      encoder.request_packet_with_data(72, 2, "", "x" * (65_535 * 4))
    end
  end

  test "read_reply appends additional payload bytes" do
    header = "\x01" + ("\x00" * 3) + [1].pack("V") + ("\x00" * 24)
    socket = FakeSocket.new(header, "data")
    connection = build_connection(socket: socket)

    reply = connection.send(:read_reply)

    assert_equal 36, reply.bytesize
    assert_equal "data", reply[-4, 4]
  end

  test "read_reply queues events that arrive before the expected reply" do
    event = "\x00" * 32
    event.setbyte(0, 12)
    reply = "\x00" * 32
    reply.setbyte(0, 1)
    reply[2, 2] = [5].pack("v")
    connection = build_connection(socket: FakeSocket.new(event, reply))

    result = connection.send(:read_reply, 5)

    assert_equal reply, result
    assert_equal({ type: :exposure }, connection.next_event)
  end

  test "read_reply raises contextual X11 protocol errors" do
    error_packet = "\x00" * 32
    error_packet.setbyte(1, 3)
    error_packet[2, 2] = [7].pack("v")
    error_packet[4, 4] = [99].pack("V")
    error_packet[8, 2] = [2].pack("v")
    error_packet.setbyte(10, 16)
    connection = build_connection(socket: FakeSocket.new(error_packet))

    error = assert_raise(RBGL::GUI::BackendUnavailable) do
      connection.send(:read_reply, 7)
    end

    assert_includes error.message, "request 7"
    assert_includes error.message, "opcode 16.2"
  end

  test "transport buffers partial X11 packets" do
    reader, writer = IO.pipe
    transport = RBGL::GUI::X11::Transport.new(reader)

    writer.write("hello")
    writer.flush
    assert_equal 1, transport.pending

    writer.write("!!!")
    writer.flush

    assert_equal "hello!!!", transport.read_exact(8)
    assert_equal 0, transport.pending
  ensure
    reader&.close unless reader&.closed?
    writer&.close unless writer&.closed?
  end

  test "read_event parses X11 event payloads" do
    connection = build_connection

    events = [
      [[2, 65], ->(data) { data[1, 1] = [65].pack("C") }, { type: :key_press, keycode: 65 }],
      [[3, 66], ->(data) { data[1, 1] = [66].pack("C") }, { type: :key_release, keycode: 66 }],
      [[4, 1], ->(data) { data[1, 1] = [1].pack("C"); data[24, 4] = [10, 20].pack("ss") }, { type: :button_press, x: 10, y: 20, button: 1 }],
      [[5, 2], ->(data) { data[1, 1] = [2].pack("C"); data[24, 4] = [11, 21].pack("ss") }, { type: :button_release, x: 11, y: 21, button: 2 }],
      [[6, 0], ->(data) { data[24, 4] = [12, 22].pack("ss") }, { type: :motion_notify, x: 12, y: 22 }],
      [[12, 0], ->(_data) {}, { type: :exposure }],
      [[22, 0], ->(data) { data[20, 4] = [320, 240].pack("vv") }, { type: :configure_notify, width: 320, height: 240 }],
      [
        [33, 32],
        lambda do |data|
          data[1, 1] = [32].pack("C")
          data[4, 4] = [7].pack("V")
          data[8, 4] = [68].pack("V")
          data[12, 20] = [77, 1, 2, 3, 4].pack("V5")
        end,
        { type: :client_message, format: 32, window: 7, message_type: 68, data32: [77, 1, 2, 3, 4] }
      ],
      [[99, 0], ->(_data) {}, { type: :unknown, code: 99 }]
    ]

    events.each do |(type, _code), builder, expected|
      payload = "\x00" * 32
      payload[0, 1] = [type].pack("C")
      builder.call(payload)
      connection.instance_variable_set(:@socket, FakeSocket.new(payload))
      connection.instance_variable_set(:@transport, nil)

      assert_equal expected, connection.send(:read_event)
    end
  end

  test "atom resolves built-ins caches protocol atoms and passes through integers" do
    connection = build_connection
    interned = []
    connection.define_singleton_method(:intern_atom) do |name, only_if_exists: false|
      interned << [name, only_if_exists]
      {
        "WM_PROTOCOLS" => 68,
        "WM_DELETE_WINDOW" => 69,
        "custom" => 70
      }.fetch(name)
    end

    assert_equal 39, connection.atom(:wm_name)
    assert_equal 31, connection.atom(:string)
    assert_equal 4, connection.atom(:atom)
    assert_equal 68, connection.atom(:wm_protocols)
    assert_equal 68, connection.wm_protocols_atom
    assert_equal 69, connection.wm_delete_window_atom
    assert_equal 5, connection.atom(5)
    assert_equal 70, connection.atom(:custom)
    assert_equal 68, connection.atom(:wm_protocols)
    assert_equal 69, connection.atom(:wm_delete_window)
    assert_equal 3, interned.size
  end

  test "atom cache does not retain failed zero resolutions" do
    resolutions = [0, 77]
    cache = RBGL::GUI::X11::AtomCache.new { resolutions.shift }

    assert_equal 0, cache.fetch(:optional)
    assert_equal 77, cache.fetch(:optional)
    assert_equal 77, cache.fetch(:optional)
  end

  test "key_for_keycode loads and caches the server keyboard mapping" do
    reply = "\x00" * 48
    reply.setbyte(0, 1)
    reply.setbyte(1, 2)
    reply[2, 2] = [1].pack("v")
    reply[4, 4] = [4].pack("V")
    reply[32, 16] = [0xFF1B, 0, 0x61, 0x41].pack("V4")
    socket = FakeSocket.new(reply)
    connection = build_connection(socket: socket)
    connection.instance_variable_set(:@minimum_keycode, 8)
    connection.instance_variable_set(:@maximum_keycode, 9)

    assert_equal :escape, connection.key_for_keycode(8)
    assert_equal :a, connection.key_for_keycode(9)
    assert_equal 1, socket.writes.size
    assert_equal 101, socket.writes.first.getbyte(0)
  end

  test "key mapper normalizes common keysyms and preserves unknown codes" do
    assert_equal :left, RBGL::GUI::X11::KeyMapper.key(0xFF51, fallback: 113)
    assert_equal :one, RBGL::GUI::X11::KeyMapper.key(0x31, fallback: 10)
    assert_equal :a, RBGL::GUI::X11::KeyMapper.key(0x41, fallback: 38)
    assert_equal 200, RBGL::GUI::X11::KeyMapper.key(0, fallback: 200)
  end

  test "pixel encoder uses visual masks and scanline padding" do
    framebuffer = RBGL::Engine::Framebuffer.new(1, 1)
    framebuffer.set_pixel(0, 0, Larb::Color.red)
    encoder = RBGL::GUI::X11::PixelEncoder.new(
      bits_per_pixel: 24,
      scanline_pad: 32,
      visual_class: 4,
      red_mask: 0xFF0000,
      green_mask: 0x00FF00,
      blue_mask: 0x0000FF
    )

    bytes = encoder.encode(framebuffer)

    assert_equal [0, 0, 255, 0], bytes.bytes
    assert_equal 4, encoder.bytes_per_line
    assert_equal 3, encoder.bytes_per_pixel
  end

  test "pixel encoder rejects indexed color visuals" do
    assert_raise(RBGL::GUI::BackendUnavailable) do
      RBGL::GUI::X11::PixelEncoder.new(
        bits_per_pixel: 8,
        scanline_pad: 8,
        visual_class: 3,
        red_mask: 0,
        green_mask: 0,
        blue_mask: 0
      )
    end
  end

  private

  def build_connection(socket: FakeSocket.new)
    connection = RBGL::GUI::X11::Connection.allocate
    connection.instance_variable_set(:@socket, socket)
    connection.instance_variable_set(:@pending_events, [])
    connection.instance_variable_set(:@pending_replies, {})
    connection.instance_variable_set(:@sequence, 0)
    connection.instance_variable_set(:@default_screen, 0)
    connection.instance_variable_set(:@maximum_request_length, 65_535)
    connection
  end

  def build_setup_data
    data = "\x00" * 112
    data[4, 4] = [0x1000].pack("V")
    data[8, 4] = [0x0FFF].pack("V")
    data[18, 2] = [65_535].pack("v")
    data.setbyte(20, 1)
    data.setbyte(21, 1)
    data.setbyte(26, 8)
    data.setbyte(27, 9)
    data[32, 8] = [24, 32, 32, 0, 0].pack("CCCCV")
    data[40, 4] = [10].pack("V")
    data[48, 4] = [0xFFFFFF].pack("V")
    data[52, 4] = [0x000000].pack("V")
    data[72, 4] = [20].pack("V")
    data.setbyte(78, 24)
    data.setbyte(79, 1)
    data.setbyte(80, 24)
    data[82, 2] = [1].pack("v")
    data[88, 4] = [20].pack("V")
    data.setbyte(92, 4)
    data[96, 4] = [0x00FF0000].pack("V")
    data[100, 4] = [0x0000FF00].pack("V")
    data[104, 4] = [0x000000FF].pack("V")
    data
  end

  def xauthority_field(value)
    [value.bytesize].pack("n") + value
  end
end

class X11BackendTest < Test::Unit::TestCase
  test "present returns false when no window handle is available" do
    backend = RBGL::GUI::X11::Backend.allocate
    backend.instance_variable_set(:@handle, nil)

    assert_false backend.present(RBGL::Engine::Framebuffer.new(1, 1))
  end

  test "present returns true after flushing image data" do
    backend = RBGL::GUI::X11::Backend.allocate
    framebuffer = RBGL::Engine::Framebuffer.new(2, 2)
    flushed = 0
    put_image_args = nil
    display = Object.new
    display.define_singleton_method(:root_depth) { 24 }
    display.define_singleton_method(:bits_per_pixel) { 32 }
    display.define_singleton_method(:scanline_pad) { 32 }
    display.define_singleton_method(:visual_class) { 4 }
    display.define_singleton_method(:red_mask) { 0x00FF0000 }
    display.define_singleton_method(:green_mask) { 0x0000FF00 }
    display.define_singleton_method(:blue_mask) { 0x000000FF }
    display.define_singleton_method(:put_image) { |**kwargs| put_image_args = kwargs }
    display.define_singleton_method(:flush) { flushed += 1 }

    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@handle, 9)
    backend.instance_variable_set(:@windows, { 9 => { gc: 12 } })

    assert_true backend.present(framebuffer)
    assert_equal 1, flushed
    assert_equal 9, put_image_args[:drawable]
    assert_equal 12, put_image_args[:gc]
  end
end

class X11BackendTest < Test::Unit::TestCase
  class FakeDisplay
    attr_reader :create_window_calls, :change_property_calls, :wm_delete_window_calls, :map_calls, :create_gc_calls
    attr_reader :put_image_calls, :destroy_window_calls
    attr_reader :root_depth, :root, :root_visual, :black_pixel
    attr_reader :bits_per_pixel, :scanline_pad, :visual_class, :red_mask, :green_mask, :blue_mask

    def initialize
      @ids = [101, 202]
      @create_window_calls = []
      @change_property_calls = []
      @wm_delete_window_calls = []
      @map_calls = []
      @create_gc_calls = []
      @put_image_calls = []
      @destroy_window_calls = []
      @root_depth = 24
      @root = 1
      @root_visual = 2
      @black_pixel = 0
      @bits_per_pixel = 32
      @scanline_pad = 32
      @visual_class = 4
      @red_mask = 0x00FF0000
      @green_mask = 0x0000FF00
      @blue_mask = 0x000000FF
    end

    def generate_id
      @ids.shift
    end

    def create_window(**kwargs)
      @create_window_calls << kwargs
    end

    def change_property(*args, **kwargs)
      @change_property_calls << [args, kwargs]
    end

    def enable_wm_delete_window(window)
      @wm_delete_window_calls << window
    end

    def map_window(window)
      @map_calls << window
    end

    def flush
    end

    def create_gc(gc_id, drawable)
      @create_gc_calls << [gc_id, drawable]
    end

    def put_image(**kwargs)
      @put_image_calls << kwargs
    end

    def pending
      @events&.any? ? 1 : 0
    end

    def next_event
      @events.shift
    end

    def set_events(events)
      @events = events.dup
    end

    def destroy_window(window)
      @destroy_window_calls << window
    end

    def close
      @closed = true
    end

    def wm_delete_window_atom
      77
    end

    def wm_protocols_atom
      68
    end

    def key_for_keycode(keycode)
      { 65 => :escape, 66 => :a }.fetch(keycode, keycode)
    end
  end

  test "setup_window registers WM_DELETE_WINDOW protocol" do
    backend = RBGL::GUI::X11::Backend.allocate
    display = FakeDisplay.new
    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@windows, {})

    backend.send(:setup_window, 320, 240, "RBGL")

    assert_equal [101], display.wm_delete_window_calls
    assert_equal [[202, 101]], display.create_gc_calls
  end

  test "present uploads framebuffer bytes to X11" do
    backend = RBGL::GUI::X11::Backend.allocate
    display = FakeDisplay.new
    framebuffer = RBGL::Engine::Framebuffer.new(2, 2)
    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@handle, 101)
    backend.instance_variable_set(:@windows, { 101 => { gc: 202 } })

    backend.present(framebuffer)

    assert_equal 1, display.put_image_calls.size
    assert_equal :z_pixmap, display.put_image_calls.first[:format]
    assert_equal 101, display.put_image_calls.first[:drawable]
    assert_equal 202, display.put_image_calls.first[:gc]
  end

  test "poll_events converts X11 raw events to GUI events" do
    backend = RBGL::GUI::X11::Backend.allocate
    display = FakeDisplay.new
    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@handle, 101)
    backend.instance_variable_set(:@windows, { 101 => { should_close: false } })
    display.set_events([
      { type: :key_press, keycode: 65 },
      { type: :button_press, x: 1, y: 2, button: 1 },
      { type: :motion_notify, x: 3, y: 4 },
      { type: :configure_notify, width: 320, height: 240 }
    ])

    events = backend.poll_events

    assert_equal [:key_press, :mouse_press, :mouse_move, :resize], events.map(&:type)
    assert_equal :escape, events.first.key
    assert_equal 65, events.first.keycode
  end

  test "close destroys the current window and clears the handle" do
    backend = RBGL::GUI::X11::Backend.allocate
    display = FakeDisplay.new
    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@handle, 101)
    backend.instance_variable_set(:@windows, { 101 => { should_close: false } })

    backend.close

    assert_equal [101], display.destroy_window_calls
    assert_nil backend.instance_variable_get(:@handle)
  end

  test "convert_event handles key mouse and resize event kinds" do
    backend = RBGL::GUI::X11::Backend.allocate
    backend.instance_variable_set(:@display, FakeDisplay.new)

    events = [
      backend.send(:convert_event, type: :key_press, keycode: 65),
      backend.send(:convert_event, type: :key_release, keycode: 66),
      backend.send(:convert_event, type: :button_press, x: 1, y: 2, button: 1),
      backend.send(:convert_event, type: :button_release, x: 3, y: 4, button: 2),
      backend.send(:convert_event, type: :motion_notify, x: 5, y: 6),
      backend.send(:convert_event, type: :configure_notify, width: 320, height: 240)
    ]

    assert_equal [:key_press, :key_release, :mouse_press, :mouse_release, :mouse_move, :resize], events.map(&:type)
    assert_equal :escape, events[0].key
    assert_equal :a, events[1].key
  end

  test "convert_event closes only matching wm delete messages" do
    backend = RBGL::GUI::X11::Backend.allocate
    display = FakeDisplay.new
    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@handle, 101)
    backend.instance_variable_set(:@windows, { 101 => { should_close: false } })

    ignored = backend.send(
      :convert_event,
      type: :client_message,
      window: 101,
      message_type: 68,
      data32: [12]
    )
    event = backend.send(
      :convert_event,
      type: :client_message,
      window: 101,
      message_type: 68,
      data32: [77]
    )

    assert_nil ignored
    assert_equal :close, event.type
    assert_true backend.should_close?
  end

  test "convert_event ignores client messages with a different message type" do
    backend = RBGL::GUI::X11::Backend.allocate
    display = FakeDisplay.new
    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@handle, 101)
    backend.instance_variable_set(:@windows, { 101 => { should_close: false } })

    event = backend.send(
      :convert_event,
      type: :client_message,
      window: 101,
      message_type: 12,
      data32: [77]
    )

    assert_nil event
    assert_false backend.should_close?
  end

  test "convert_event ignores client messages for other windows" do
    backend = RBGL::GUI::X11::Backend.allocate
    display = FakeDisplay.new
    backend.instance_variable_set(:@display, display)
    backend.instance_variable_set(:@handle, 101)
    backend.instance_variable_set(:@windows, { 101 => { should_close: false } })

    event = backend.send(
      :convert_event,
      type: :client_message,
      window: 202,
      message_type: 68,
      data32: [77]
    )

    assert_nil event
    assert_false backend.should_close?
  end
end
