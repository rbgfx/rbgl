# frozen_string_literal: true

require "socket"

module RBGL
  module GUI
    module X11
      class Connection
        attr_reader :default_screen, :resource_id_base, :resource_id_mask
        attr_reader :root, :root_depth, :root_visual, :white_pixel, :black_pixel

        def initialize(display_name)
          host, display_num, _screen_num = parse_display_name(display_name)
          @socket = connect(host, display_num)
          @next_seq = 1
          @resource_id_counter = 0
          @pending_events = []

          handshake
        end

        def generate_id
          id = @resource_id_base | @resource_id_counter
          @resource_id_counter += 1
          id
        end

        def flush
          @socket.flush
        end

        def atom(name)
          @atom_cache ||= {
            wm_name: 39,
            string: 31,
            atom: 4
          }
          @atom_cache[name] ||= resolve_atom(name)
        end

        def wm_delete_window_atom
          atom(:wm_delete_window)
        end

        def enable_wm_delete_window(window)
          change_property(window, :wm_protocols, :atom, [wm_delete_window_atom], format: 32)
        end

        def pending
          ready = IO.select([@socket], nil, nil, 0)
          ready ? 1 : 0
        end

        def create_window(depth:, wid:, parent:, x:, y:, width:, height:,
                          border_width:, window_class:, visual:, value_mask:, values:)
          class_val = case window_class
                      when :input_output then 1
                      when :input_only then 2
                      else 0
                      end

          mask = 0
          value_list = []

          if value_mask.include?(:back_pixel)
            mask |= 0x0002
            value_list << values[:back_pixel]
          end

          if value_mask.include?(:event_mask)
            mask |= 0x0800
            event_mask = 0
            values[:event_mask].each do |ev|
              event_mask |= case ev
                            when :exposure then 0x8000
                            when :key_press then 0x0001
                            when :key_release then 0x0002
                            when :button_press then 0x0004
                            when :button_release then 0x0008
                            when :pointer_motion then 0x0040
                            when :structure_notify then 0x020000
                            else 0
                            end
            end
            value_list << event_mask
          end

          request = [
            depth,
            wid,
            parent,
            x, y,
            width, height,
            border_width,
            class_val,
            visual,
            mask
          ].pack("CVVSSSSSVV") + value_list.pack("V*")

          send_request(1, request)
        end

        def map_window(wid)
          send_request(8, [wid].pack("V"))
        end

        def destroy_window(wid)
          send_request(4, [wid].pack("V"))
        end

        def create_gc(gc_id, drawable, values = {})
          mask = 0
          value_list = []

          if values[:foreground]
            mask |= 0x0004
            value_list << values[:foreground]
          end

          if values[:background]
            mask |= 0x0008
            value_list << values[:background]
          end

          request = [gc_id, drawable, mask].pack("VVV") + value_list.pack("V*")
          send_request(55, request)
        end

        def put_image(format:, drawable:, gc:, width:, height:, dst_x:, dst_y:, depth:, data:)
          format_byte = case format
                        when :bitmap then 0
                        when :xy_pixmap then 1
                        when :z_pixmap then 2
                        else 2
                        end

          left_pad = 0

          header = [
            drawable,
            gc,
            width, height,
            dst_x, dst_y,
            left_pad,
            depth
          ].pack("VVvvvvCC") + "\x00\x00"

          send_request_with_data(72, format_byte, header, data)
        end

        def change_property(window, property, type, data, mode: :replace, format: 8)
          mode_val = case mode
                     when :replace then 0
                     when :prepend then 1
                     when :append then 2
                     else 0
                     end

          property_atom = atom(property)
          type_atom = atom(type)
          data_bytes, value_count = pack_property_data(data, format)

          request = [
            window,
            property_atom,
            type_atom,
            format,
            value_count
          ].pack("VVVCV") + "\x00\x00\x00" + pad_to_4(data_bytes)

          send_request(18, request, mode_val)
        end

        def intern_atom(name, only_if_exists: false)
          request = [
            name.bytesize,
            0
          ].pack("vv") + pad_to_4(name)

          send_request(16, request, only_if_exists ? 1 : 0)
          flush

          reply = read_reply
          return 0 unless reply

          reply[8, 4].unpack1("V")
        end

        def next_event
          return @pending_events.shift unless @pending_events.empty?

          read_events
          @pending_events.shift
        end

        def read_events
          while pending > 0
            event = read_event
            @pending_events << event if event
          end
        end

        private

        def parse_display_name(name)
          if name =~ /^(?:(.*):)?(\d+)(?:\.(\d+))?$/
            host = ::Regexp.last_match(1)
            host = nil if host&.empty?
            [host, ::Regexp.last_match(2).to_i, (::Regexp.last_match(3) || 0).to_i]
          else
            raise "Invalid display name: #{name}"
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

        def handshake
          init_request = [
            0x6C,
            0,
            11, 0,
            0, 0,
            0, 0
          ].pack("CCvvvvvv")

          @socket.write(init_request)
          @socket.flush

          header = @socket.read(8)
          status = header.unpack1("C")

          raise "X11 connection failed" unless status == 1

          additional_length = header[6, 2].unpack1("v")
          data = @socket.read(additional_length * 4)

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
          length = (4 + data.bytesize + 3) / 4
          header = [opcode, extra, length].pack("CCv")

          padding_size = length * 4 - 4 - data.bytesize
          padded_data = data + ("\x00" * padding_size)

          @socket.write(header + padded_data)
          @next_seq += 1
        end

        def send_request_with_data(opcode, extra, header_data, bulk_data)
          total_data = header_data + bulk_data
          length = (4 + total_data.bytesize + 3) / 4

          header = [opcode, extra, length].pack("CCv")
          padding_size = length * 4 - 4 - total_data.bytesize
          padded = total_data + ("\x00" * padding_size)

          @socket.write(header + padded)
          @next_seq += 1
        end

        def read_reply
          header = @socket.read(32)
          return nil unless header && header.bytesize == 32

          additional = header[4, 4].unpack1("V")
          if additional > 0
            header + @socket.read(additional * 4)
          else
            header
          end
        end

        def read_event
          data = @socket.read(32)
          return nil unless data && data.bytesize == 32

          event_type = data.unpack1("C") & 0x7F

          case event_type
          when 2
            keycode = data[1, 1].unpack1("C")
            { type: :key_press, keycode: keycode }
          when 3
            keycode = data[1, 1].unpack1("C")
            { type: :key_release, keycode: keycode }
          when 4
            x, y = data[24, 4].unpack("ss")
            button = data[1, 1].unpack1("C")
            { type: :button_press, x: x, y: y, button: button }
          when 5
            x, y = data[24, 4].unpack("ss")
            button = data[1, 1].unpack1("C")
            { type: :button_release, x: x, y: y, button: button }
          when 6
            x, y = data[24, 4].unpack("ss")
            { type: :motion_notify, x: x, y: y }
          when 12
            { type: :exposure }
          when 22
            width, height = data[20, 4].unpack("vv")
            { type: :configure_notify, width: width, height: height }
          when 33
            window = data[4, 4].unpack1("V")
            atom = data[8, 4].unpack1("V")
            { type: :client_message, window: window, data: atom }
          else
            { type: :unknown, code: event_type }
          end
        end

        def resolve_atom(name)
          case name
          when :wm_name then 39
          when :string then 31
          when :atom then 4
          when :wm_protocols then intern_atom("WM_PROTOCOLS")
          when :wm_delete_window then intern_atom("WM_DELETE_WINDOW")
          else
            name.is_a?(Integer) ? name : intern_atom(name.to_s)
          end
        end

        def pack_property_data(data, format)
          case format
          when 8
            bytes = data.to_s
            [bytes, bytes.bytesize]
          when 16
            values = Array(data)
            [values.pack("v*"), values.size]
          when 32
            values = Array(data)
            [values.pack("V*"), values.size]
          else
            raise ArgumentError, "Unsupported property format: #{format}"
          end
        end

        def pad_to_4(str)
          padding = (4 - str.bytesize % 4) % 4
          str + ("\x00" * padding)
        end

        def pad_length(len)
          ((len + 3) / 4) * 4
        end
      end
    end
  end
end
