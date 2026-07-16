# frozen_string_literal: true

require "socket"
require_relative "../backend"
require_relative "atom_cache"
require_relative "event_parser"
require_relative "request_encoder"
require_relative "transport"
require_relative "x_authority"

module RBGL
  module GUI
    module X11
      class Connection
        ATOM_NAMES = {
          wm_protocols: "WM_PROTOCOLS",
          wm_delete_window: "WM_DELETE_WINDOW"
        }.freeze

        attr_reader :default_screen, :resource_id_base, :resource_id_mask
        attr_reader :root, :root_depth, :root_visual, :white_pixel, :black_pixel

        def initialize(display_name, env: ENV)
          host, display_num, screen_num = parse_display_name(display_name)
          @socket = connect(host, display_num)
          @transport = Transport.new(@socket)
          @resource_id_counter = 0
          @pending_events = []
          @pending_replies = {}
          @sequence = 0
          @default_screen = screen_num

          handshake(host: host, display_num: display_num, env: env)
        rescue StandardError
          @transport&.close
          raise
        end

        def generate_id
          masked_counter = @resource_id_counter & @resource_id_mask
          raise GUI::BackendUnavailable, "X11 resource ID space exhausted" if masked_counter != @resource_id_counter

          id = @resource_id_base | masked_counter
          @resource_id_counter += 1
          id
        end

        def flush
          transport.flush
        end

        def atom(name)
          atom_cache.fetch(name)
        end

        def wm_delete_window_atom
          atom(:wm_delete_window)
        end

        def wm_protocols_atom
          atom(:wm_protocols)
        end

        def enable_wm_delete_window(window)
          change_property(window, :wm_protocols, :atom, [wm_delete_window_atom], format: 32)
        end

        def pending
          @pending_events.length + transport.pending
        end

        def create_window(depth:, wid:, parent:, x:, y:, width:, height:,
                          border_width:, window_class:, visual:, value_mask:, values:)
          request = request_encoder.create_window_data(
            depth: depth,
            wid: wid,
            parent: parent,
            x: x,
            y: y,
            width: width,
            height: height,
            border_width: border_width,
            window_class: window_class,
            visual: visual,
            value_mask: value_mask,
            values: values
          )
          send_request(1, request)
        end

        def map_window(wid)
          send_request(8, [wid].pack("V"))
        end

        def destroy_window(wid)
          send_request(4, [wid].pack("V"))
        end

        def create_gc(gc_id, drawable, values = {})
          request = request_encoder.create_gc_data(gc_id, drawable, values)
          send_request(55, request)
        end

        def put_image(format:, drawable:, gc:, width:, height:, dst_x:, dst_y:, depth:, data:)
          format_byte, header, image_data = request_encoder.put_image_data(
            format: format,
            drawable: drawable,
            gc: gc,
            width: width,
            height: height,
            dst_x: dst_x,
            dst_y: dst_y,
            depth: depth,
            data: data
          )
          send_request_with_data(72, format_byte, header, image_data)
        end

        def change_property(window, property, type, data, mode: :replace, format: 8)
          property_atom = atom(property)
          type_atom = atom(type)
          mode_val, request = request_encoder.change_property_data(
            window,
            property_atom,
            type_atom,
            data,
            mode: mode,
            format: format
          )
          send_request(18, request, mode_val)
        end

        def intern_atom(name, only_if_exists: false)
          request = request_encoder.intern_atom_data(name)
          sequence = send_request(16, request, only_if_exists ? 1 : 0)
          flush

          reply = read_reply(sequence)
          return 0 unless reply

          reply[8, 4].unpack1("V")
        end

        def next_event
          return @pending_events.shift unless @pending_events.empty?

          read_events
          @pending_events.shift
        end

        def read_events
          while transport.pending > 0
            event = read_event
            @pending_events << event if event
          end
        end

        def close
          transport.close
        end

        private

        def parse_display_name(name)
          if name =~ /^(?:(.*):)?(\d+)(?:\.(\d+))?$/
            host = ::Regexp.last_match(1)
            host = nil if host&.empty?
            [host, ::Regexp.last_match(2).to_i, (::Regexp.last_match(3) || 0).to_i]
          else
            raise GUI::BackendUnavailable, "Invalid X11 display name: #{name}"
          end
        end

        def connect(host, display_num)
          if host.nil? || host.empty? || host == "unix"
            socket_path = "/tmp/.X11-unix/X#{display_num}"
            UNIXSocket.new(socket_path)
          else
            TCPSocket.new(host, 6000 + display_num)
          end
        end

        def handshake(host: nil, display_num: 0, env: ENV)
          auth_host = local_display_host?(host) ? nil : host
          cookie = XAuthority.cookie_for(host: auth_host, display_number: display_num, env: env)
          auth_name = cookie ? XAuthority::AUTH_NAME : ""
          auth_data = cookie || ""
          init_request = [0x6C, 0, 11, 0, auth_name.bytesize, auth_data.bytesize, 0].pack("CCvvvvv")
          init_request << pad_to_4(auth_name)
          init_request << pad_to_4(auth_data)

          transport.write(init_request)
          transport.flush

          header = transport.read_exact(8)
          raise GUI::BackendUnavailable, "X11 connection closed during handshake" unless header&.bytesize == 8

          status = header.unpack1("C")
          unless status == 1
            reason_length = header.getbyte(1)
            reason = reason_length.positive? ? transport.read_exact(pad_length(reason_length)).byteslice(0, reason_length) : nil
            detail = reason && !reason.empty? ? ": #{reason}" : ""
            raise GUI::BackendUnavailable, "X11 connection failed#{detail}"
          end

          additional_length = header[6, 2].unpack1("v")
          data = transport.read_exact(additional_length * 4)

          parse_server_info(data)
        end

        def parse_server_info(data)
          @resource_id_base = data[4, 4].unpack1("V")
          @resource_id_mask = data[8, 4].unpack1("V")

          vendor_length = data[16, 2].unpack1("v")
          num_screens = data[20, 1].unpack1("C")
          num_formats = data[21, 1].unpack1("C")

          offset = 32 + pad_length(vendor_length) + num_formats * 8

          if num_screens > 0
            @root = data[offset, 4].unpack1("V")
            @root_depth = data[offset + 38, 1].unpack1("C")
            @root_visual = data[offset + 32, 4].unpack1("V")
            @white_pixel = data[offset + 8, 4].unpack1("V")
            @black_pixel = data[offset + 12, 4].unpack1("V")
          end
        end

        def send_request(opcode, data, extra = 0)
          transport.write(request_encoder.request_packet(opcode, data, extra))
          next_sequence
        end

        def send_request_with_data(opcode, extra, header_data, bulk_data)
          transport.write(request_encoder.request_packet_with_data(opcode, extra, header_data, bulk_data))
          next_sequence
        end

        def read_reply(expected_sequence = nil)
          return @pending_replies.delete(expected_sequence) if expected_sequence && @pending_replies.key?(expected_sequence)

          loop do
            packet = read_packet
            type = packet.getbyte(0)
            sequence = packet.byteslice(2, 2).unpack1("v")

            case type
            when 0
              raise_protocol_error(packet)
            when 1
              return packet if expected_sequence.nil? || sequence == expected_sequence

              @pending_replies[sequence] = packet
            else
              event = event_parser.parse(packet)
              @pending_events << event if event
            end
          end
        end

        def read_event
          packet = read_packet
          type = packet.getbyte(0)
          return raise_protocol_error(packet) if type.zero?

          if type == 1
            sequence = packet.byteslice(2, 2).unpack1("v")
            @pending_replies[sequence] = packet
            return nil
          end

          event_parser.parse(packet)
        end

        def resolve_atom(name)
          return name if name.is_a?(Integer)

          intern_atom(ATOM_NAMES.fetch(name, name.to_s))
        end

        def pad_length(len)
          ((len + 3) / 4) * 4
        end

        def local_display_host?(host)
          host.nil? || host.empty? || host == "unix"
        end

        def transport
          @transport ||= Transport.new(@socket)
        end

        def request_encoder
          @request_encoder ||= RequestEncoder.new
        end

        def event_parser
          @event_parser ||= EventParser.new
        end

        def atom_cache
          @atom_cache ||= AtomCache.new { |name| resolve_atom(name) }
        end

        def read_packet
          header = transport.read_exact(32)
          return header unless header.getbyte(0) == 1

          additional = header.byteslice(4, 4).unpack1("V")
          additional.positive? ? header + transport.read_exact(additional * 4) : header
        rescue EOFError => error
          raise GUI::BackendUnavailable, error.message
        end

        def raise_protocol_error(packet)
          error_code = packet.getbyte(1)
          sequence = packet.byteslice(2, 2).unpack1("v")
          bad_value = packet.byteslice(4, 4).unpack1("V")
          minor_opcode = packet.byteslice(8, 2).unpack1("v")
          major_opcode = packet.getbyte(10)
          raise GUI::BackendUnavailable,
                "X11 protocol error #{error_code} for request #{sequence} " \
                "(opcode #{major_opcode}.#{minor_opcode}, value #{bad_value})"
        end

        def next_sequence
          @sequence = (@sequence + 1) & 0xFFFF
        end

        def pack_property_data(data, format)
          request_encoder.pack_property_data(data, format)
        end

        def pad_to_4(str)
          request_encoder.pad_to_4(str)
        end
      end
    end
  end
end
