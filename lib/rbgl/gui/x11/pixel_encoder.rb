# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      class PixelEncoder
        TRUE_COLOR_CLASSES = [4, 5].freeze
        IMAGE_BYTE_ORDERS = %i[little big].freeze

        attr_reader :bytes_per_pixel

        def initialize(bits_per_pixel:, scanline_pad:, visual_class:, red_mask:, green_mask:, blue_mask:,
                       image_byte_order: :little)
          unless TRUE_COLOR_CLASSES.include?(visual_class)
            raise GUI::BackendUnavailable, "X11 root visual must be TrueColor or DirectColor"
          end
          unless [16, 24, 32].include?(bits_per_pixel)
            raise GUI::BackendUnavailable, "Unsupported X11 pixel width: #{bits_per_pixel}"
          end
          unless IMAGE_BYTE_ORDERS.include?(image_byte_order)
            raise GUI::BackendUnavailable, "Unsupported X11 image byte order: #{image_byte_order}"
          end

          @bytes_per_pixel = bits_per_pixel / 8
          @scanline_alignment = scanline_pad / 8
          @image_byte_order = image_byte_order
          @red_lut = channel_lut(red_mask)
          @green_lut = channel_lut(green_mask)
          @blue_lut = channel_lut(blue_mask)
          @standard_bgra = bits_per_pixel == 32 && image_byte_order == :little &&
                           red_mask == 0x00FF0000 && green_mask == 0x0000FF00 && blue_mask == 0x000000FF
        end

        def bytes_per_line(width)
          aligned_length(width * @bytes_per_pixel)
        end

        def encode(framebuffer)
          stride = bytes_per_line(framebuffer.width)
          if @standard_bgra
            return pad_rows(framebuffer.to_bgra_bytes, framebuffer.width * 4, stride, framebuffer.height)
          end

          output = String.new(capacity: stride * framebuffer.height, encoding: Encoding::BINARY)
          row_pixels = 0

          framebuffer.each_packed_pixel do |color|
            append_pixel(
              output,
              @red_lut[(color >> 16) & 0xFF] |
              @green_lut[(color >> 8) & 0xFF] |
              @blue_lut[color & 0xFF]
            )
            row_pixels += 1
            next unless row_pixels == framebuffer.width

            append_padding(output, stride - (framebuffer.width * @bytes_per_pixel))
            row_pixels = 0
          end

          output
        end

        def encode_rgba(buffer, width, height)
          if @standard_bgra
            output = String.new(capacity: bytes_per_line(width) * height, encoding: Encoding::BINARY)
            encode_standard_rgba(output, buffer, width, height)
            return output
          end

          encode_arbitrary_rgba(buffer, width, height)
        end

        private

        def encode_standard_rgba(output, buffer, width, height)
          stride = bytes_per_line(width)
          row_bytes = width * 4
          byte_index = 0

          height.times do
            width.times do
              output << buffer.getbyte(byte_index + 2) << buffer.getbyte(byte_index + 1) <<
                        buffer.getbyte(byte_index) << buffer.getbyte(byte_index + 3)
              byte_index += 4
            end
            append_padding(output, stride - row_bytes)
          end
        end

        def encode_arbitrary_rgba(buffer, width, height)
          stride = bytes_per_line(width)
          output = String.new(capacity: stride * height, encoding: Encoding::BINARY)
          byte_index = 0

          height.times do
            width.times do
              append_pixel(
                output,
                @red_lut[buffer.getbyte(byte_index)] |
                @green_lut[buffer.getbyte(byte_index + 1)] |
                @blue_lut[buffer.getbyte(byte_index + 2)]
              )
              byte_index += 4
            end
            append_padding(output, stride - (width * @bytes_per_pixel))
          end

          output
        end

        def append_pixel(output, pixel)
          if @image_byte_order == :little
            index = 0
            while index < @bytes_per_pixel
              output << ((pixel >> (index * 8)) & 0xFF)
              index += 1
            end
          else
            index = @bytes_per_pixel - 1
            while index >= 0
              output << ((pixel >> (index * 8)) & 0xFF)
              index -= 1
            end
          end
        end

        def append_padding(output, length)
          output << ("\x00" * length) if length.positive?
        end

        def channel_lut(mask)
          raise GUI::BackendUnavailable, "X11 visual has an empty color mask" if mask.zero?

          shift = 0
          shifted = mask
          while shifted & 1 == 0
            shifted >>= 1
            shift += 1
          end
          maximum = shifted
          Array.new(256) { |value| ((value * maximum / 255.0).round << shift) }.freeze
        end

        def pad_rows(bytes, row_bytes, stride, height)
          return bytes if row_bytes == stride

          output = String.new(capacity: stride * height, encoding: Encoding::BINARY)
          height.times do |row|
            output << bytes.byteslice(row * row_bytes, row_bytes)
            append_padding(output, stride - row_bytes)
          end
          output
        end

        def aligned_length(length)
          return length if @scanline_alignment <= 1

          ((length + @scanline_alignment - 1) / @scanline_alignment) * @scanline_alignment
        end
      end
    end
  end
end
