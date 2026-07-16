# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      class PixelEncoder
        TRUE_COLOR_CLASSES = [4, 5].freeze

        attr_reader :bytes_per_line, :bytes_per_pixel

        def initialize(bits_per_pixel:, scanline_pad:, visual_class:, red_mask:, green_mask:, blue_mask:)
          unless TRUE_COLOR_CLASSES.include?(visual_class)
            raise GUI::BackendUnavailable, "X11 root visual must be TrueColor or DirectColor"
          end
          unless [16, 24, 32].include?(bits_per_pixel)
            raise GUI::BackendUnavailable, "Unsupported X11 pixel width: #{bits_per_pixel}"
          end

          @bytes_per_pixel = bits_per_pixel / 8
          @scanline_alignment = scanline_pad / 8
          @red = channel_layout(red_mask)
          @green = channel_layout(green_mask)
          @blue = channel_layout(blue_mask)
        end

        def encode(framebuffer)
          @bytes_per_line = aligned_length(framebuffer.width * @bytes_per_pixel)
          output = String.new(capacity: @bytes_per_line * framebuffer.height, encoding: Encoding::BINARY)

          framebuffer.height.times do |y|
            framebuffer.width.times do |x|
              output << encode_color(framebuffer.get_pixel(x, y))
            end
            output << "\x00" * (@bytes_per_line - framebuffer.width * @bytes_per_pixel)
          end

          output
        end

        private

        def encode_color(color)
          pixel = encode_channel(color.r, @red) |
                  encode_channel(color.g, @green) |
                  encode_channel(color.b, @blue)

          [pixel].pack(case @bytes_per_pixel
                       when 2 then "S<"
                       when 3 then "L<"
                       when 4 then "L<"
                       end).byteslice(0, @bytes_per_pixel)
        end

        def encode_channel(value, layout)
          shift, maximum = layout
          ((value.clamp(0.0, 1.0) * maximum).round << shift)
        end

        def channel_layout(mask)
          raise GUI::BackendUnavailable, "X11 visual has an empty color mask" if mask.zero?

          shift = 0
          shifted = mask
          while shifted & 1 == 0
            shifted >>= 1
            shift += 1
          end
          [shift, shifted]
        end

        def aligned_length(length)
          return length if @scanline_alignment <= 1

          ((length + @scanline_alignment - 1) / @scanline_alignment) * @scanline_alignment
        end
      end
    end
  end
end
