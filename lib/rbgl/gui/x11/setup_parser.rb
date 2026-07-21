# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      class SetupParser
        Setup = Struct.new(
          :resource_id_base,
          :resource_id_mask,
          :maximum_request_length,
          :image_byte_order,
          :minimum_keycode,
          :maximum_keycode,
          :pixmap_formats,
          :screens,
          keyword_init: true
        )
        PixmapFormat = Struct.new(:depth, :bits_per_pixel, :scanline_pad, keyword_init: true)
        Depth = Struct.new(:depth, :visuals, keyword_init: true)
        Screen = Struct.new(
          :root,
          :white_pixel,
          :black_pixel,
          :root_visual,
          :root_depth,
          :depths,
          keyword_init: true
        ) do
          def visuals
            depths.flat_map(&:visuals)
          end
        end
        Visual = Struct.new(:id, :visual_class, :red_mask, :green_mask, :blue_mask, keyword_init: true)

        def parse(data)
          raise ArgumentError, "Truncated X11 setup response" if data.bytesize < 32

          vendor_length = data.byteslice(16, 2).unpack1("v")
          screen_count = data.getbyte(20)
          format_count = data.getbyte(21)
          format_offset = 32 + padded_length(vendor_length)
          formats = parse_formats(data, format_offset, format_count)
          screens = parse_screens(data, format_offset + (format_count * 8), screen_count)

          Setup.new(
            resource_id_base: data.byteslice(4, 4).unpack1("V"),
            resource_id_mask: data.byteslice(8, 4).unpack1("V"),
            maximum_request_length: data.byteslice(18, 2).unpack1("v"),
            image_byte_order: parse_image_byte_order(data.getbyte(22)),
            minimum_keycode: data.getbyte(26),
            maximum_keycode: data.getbyte(27),
            pixmap_formats: formats,
            screens: screens
          )
        end

        private

        def parse_formats(data, offset, count)
          count.times.map do |index|
            bytes = required_slice(data, offset + (index * 8), 8)
            PixmapFormat.new(
              depth: bytes.getbyte(0),
              bits_per_pixel: bytes.getbyte(1),
              scanline_pad: bytes.getbyte(2)
            )
          end
        end

        def parse_screens(data, offset, count)
          screens = []
          count.times do
            screen, offset = parse_screen(data, offset)
            screens << screen
          end
          screens
        end

        def parse_screen(data, offset)
          header = required_slice(data, offset, 40)
          depth_count = header.getbyte(39)
          cursor = offset + 40
          depths = []

          depth_count.times do
            depth_header = required_slice(data, cursor, 8)
            depth_value = depth_header.getbyte(0)
            visual_count = depth_header.byteslice(2, 2).unpack1("v")
            cursor += 8
            visuals = []
            visual_count.times do
              visuals << parse_visual(required_slice(data, cursor, 24))
              cursor += 24
            end
            depths << Depth.new(depth: depth_value, visuals: visuals)
          end

          screen = Screen.new(
            root: header.byteslice(0, 4).unpack1("V"),
            white_pixel: header.byteslice(8, 4).unpack1("V"),
            black_pixel: header.byteslice(12, 4).unpack1("V"),
            root_visual: header.byteslice(32, 4).unpack1("V"),
            root_depth: header.getbyte(38),
            depths: depths
          )
          [screen, cursor]
        end

        def parse_visual(bytes)
          Visual.new(
            id: bytes.byteslice(0, 4).unpack1("V"),
            visual_class: bytes.getbyte(4),
            red_mask: bytes.byteslice(8, 4).unpack1("V"),
            green_mask: bytes.byteslice(12, 4).unpack1("V"),
            blue_mask: bytes.byteslice(16, 4).unpack1("V")
          )
        end

        def required_slice(data, offset, length)
          bytes = data.byteslice(offset, length)
          raise ArgumentError, "Truncated X11 setup response" unless bytes&.bytesize == length

          bytes
        end

        def padded_length(length)
          (length + 3) & ~3
        end

        def parse_image_byte_order(value)
          { 0 => :little, 1 => :big }.fetch(value) do
            raise ArgumentError, "Unsupported X11 image byte order: #{value}"
          end
        end
      end
    end
  end
end
