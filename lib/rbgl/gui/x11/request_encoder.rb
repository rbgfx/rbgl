# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      class RequestEncoder
        EVENT_MASKS = {
          exposure: 0x8000,
          key_press: 0x0001,
          key_release: 0x0002,
          button_press: 0x0004,
          button_release: 0x0008,
          pointer_motion: 0x0040,
          structure_notify: 0x020000
        }.freeze

        WINDOW_CLASSES = {
          input_output: 1,
          input_only: 2
        }.freeze

        PROPERTY_MODES = {
          replace: 0,
          prepend: 1,
          append: 2
        }.freeze

        IMAGE_FORMATS = {
          bitmap: 0,
          xy_pixmap: 1,
          z_pixmap: 2
        }.freeze

        def create_window_data(depth:, wid:, parent:, x:, y:, width:, height:,
                               border_width:, window_class:, visual:, value_mask:, values:)
          mask = 0
          value_list = []

          if value_mask.include?(:back_pixel)
            mask |= 0x0002
            value_list << values[:back_pixel]
          end

          if value_mask.include?(:event_mask)
            mask |= 0x0800
            value_list << encode_event_mask(values[:event_mask])
          end

          data = [
            wid,
            parent,
            x, y,
            width, height,
            border_width,
            WINDOW_CLASSES.fetch(window_class),
            visual,
            mask
          ].pack("VVs<s<vvvvVV") + value_list.pack("V*")

          [depth, data]
        end

        def create_gc_data(gc_id, drawable, values = {})
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

          [gc_id, drawable, mask].pack("VVV") + value_list.pack("V*")
        end

        def put_image_data(format:, drawable:, gc:, width:, height:, dst_x:, dst_y:, depth:, data:)
          format_byte = IMAGE_FORMATS.fetch(format)
          header = [
            drawable,
            gc,
            width, height,
            dst_x, dst_y,
            0,
            depth
          ].pack("VVvvs<s<CC") + "\x00\x00"

          [format_byte, header, data]
        end

        def change_property_data(window, property_atom, type_atom, data, mode: :replace, format: 8)
          data_bytes, value_count = pack_property_data(data, format)
          request = [
            window,
            property_atom,
            type_atom,
            format,
            value_count
          ].pack("VVVCV") + "\x00\x00\x00" + pad_to_4(data_bytes)

          [PROPERTY_MODES.fetch(mode), request]
        end

        def intern_atom_data(name)
          [name.bytesize, 0].pack("vv") + pad_to_4(name)
        end

        def request_packet(opcode, data, extra = 0)
          encode_packet(opcode, extra, data)
        end

        def request_packet_with_data(opcode, extra, header_data, bulk_data)
          encode_packet(opcode, extra, header_data + bulk_data)
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
          padding = (4 - (str.bytesize % 4)) % 4
          str + ("\x00" * padding)
        end

        private

        def encode_packet(opcode, extra, data)
          length = (4 + data.bytesize + 3) / 4
          raise ArgumentError, "X11 request exceeds the 16-bit core protocol limit" if length > 65_535

          header = [opcode, extra, length].pack("CCv")
          padding = "\x00" * ((length * 4) - 4 - data.bytesize)
          header + data + padding
        end

        def encode_event_mask(events)
          Array(events).sum { |event| EVENT_MASKS.fetch(event) }
        end
      end
    end
  end
end
