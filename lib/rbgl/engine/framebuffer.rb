# frozen_string_literal: true

module RBGL
  module Engine
    class Framebuffer
      attr_reader :width, :height, :depth_buffer

      def self.from_rgba_bytes(width, height, buffer)
        new(width, height).tap { |framebuffer| framebuffer.send(:load_rgba_bytes, buffer) }
      end

      def initialize(width, height)
        resize(width, height)
      end

      def resize(width, height)
        validate_dimensions!(width, height)
        pixels = Array.new(width * height, pack_color(Larb::Color.black))
        depth_buffer = Array.new(width * height) { Float::INFINITY }

        @width = width
        @height = height
        @pixels = pixels
        @depth_buffer = depth_buffer
      end

      def color_buffer
        @pixels.map { |pixel| unpack_color(pixel) }
      end

      def each_packed_pixel(&block)
        return @pixels.each unless block

        @pixels.each(&block)
      end

      def get_pixel(x, y)
        return nil if x < 0 || x >= @width || y < 0 || y >= @height

        unpack_color(@pixels[(y * @width) + x])
      end

      def set_pixel(x, y, color)
        return if x < 0 || x >= @width || y < 0 || y >= @height

        @pixels[(y * @width) + x] = pack_color(color)
      end

      def get_depth(x, y)
        return Float::INFINITY if x < 0 || x >= @width || y < 0 || y >= @height

        @depth_buffer[(y * @width) + x]
      end

      def set_depth(x, y, depth)
        return if x < 0 || x >= @width || y < 0 || y >= @height

        @depth_buffer[(y * @width) + x] = depth
      end

      def write_pixel(x, y, color, depth, depth_test: true, depth_write: true, blend_mode: :none)
        return false if x < 0 || x >= @width || y < 0 || y >= @height
        return false unless depth.is_a?(Numeric) && depth.real? && depth.finite?

        idx = (y * @width) + x
        return false if depth_test && depth >= @depth_buffer[idx]

        @pixels[idx] = blend_mode == :alpha ? blend_pixel(@pixels[idx], color) : pack_color(color)
        @depth_buffer[idx] = depth if depth_write
        true
      end

      def clear(color: Larb::Color.black, depth: Float::INFINITY)
        @pixels.fill(pack_color(color))
        @depth_buffer.fill(depth)
      end

      def clear_color(color)
        @pixels.fill(pack_color(color))
      end

      def clear_depth(depth = Float::INFINITY)
        @depth_buffer.fill(depth)
      end

      def to_ppm
        ppm = String.new(capacity: @width * @height * 12, encoding: Encoding::BINARY)
        ppm << "P3\n#{@width} #{@height}\n255\n"
        @height.times do |y|
          @width.times do |x|
            pixel = @pixels[(y * @width) + x]
            ppm << " " unless x.zero?
            ppm << red_byte(pixel).to_s << " " << green_byte(pixel).to_s << " " << blue_byte(pixel).to_s
          end
          ppm << "\n"
        end
        ppm
      end

      def to_ppm_binary
        header = "P6\n#{@width} #{@height}\n255\n"
        pixels = packed_color_bytes(:rgb)
        header + pixels
      end

      def to_rgba_bytes
        packed_color_bytes(:rgba)
      end

      def to_bgra_bytes
        packed_color_bytes(:bgra)
      end

      private

      def validate_dimensions!(width, height)
        return if width.is_a?(Integer) && width.positive? && height.is_a?(Integer) && height.positive?

        raise ArgumentError, "Framebuffer dimensions must be positive integers"
      end

      def load_rgba_bytes(buffer)
        bytes = String.try_convert(buffer)
        raise ArgumentError, "Pixel buffer must be a String" unless bytes

        expected_size = @width * @height * 4
        unless bytes.bytesize == expected_size
          raise ArgumentError, "Pixel buffer size mismatch: expected #{expected_size}, got #{bytes.bytesize}"
        end

        @pixels = Array.new(@width * @height)
        pixel_index = 0
        byte_index = 0
        while pixel_index < @pixels.length
          @pixels[pixel_index] = pack_bytes(
            bytes.getbyte(byte_index),
            bytes.getbyte(byte_index + 1),
            bytes.getbyte(byte_index + 2),
            bytes.getbyte(byte_index + 3)
          )
          pixel_index += 1
          byte_index += 4
        end
      end

      def blend_pixel(destination, source)
        validate_color!(source)
        alpha = source.a
        inv_alpha = 1.0 - alpha
        pack_bytes(
          color_byte((source.r * alpha) + ((red_byte(destination) / 255.0) * inv_alpha)),
          color_byte((source.g * alpha) + ((green_byte(destination) / 255.0) * inv_alpha)),
          color_byte((source.b * alpha) + ((blue_byte(destination) / 255.0) * inv_alpha)),
          color_byte(alpha + ((alpha_byte(destination) / 255.0) * inv_alpha))
        )
      end

      def pack_color(color)
        validate_color!(color)
        pack_bytes(color_byte(color.r), color_byte(color.g), color_byte(color.b), color_byte(color.a))
      end

      def validate_color!(color)
        return if color.is_a?(Larb::Color)

        raise ArgumentError, "Colors must be Larb::Color values"
      end

      def packed_color_bytes(format)
        channel_count = format == :rgb ? 3 : 4
        bytes = String.new(capacity: @pixels.length * channel_count, encoding: Encoding::BINARY)

        @pixels.each do |pixel|
          case format
          when :rgb
            bytes << red_byte(pixel) << green_byte(pixel) << blue_byte(pixel)
          when :rgba
            bytes << red_byte(pixel) << green_byte(pixel) << blue_byte(pixel) << alpha_byte(pixel)
          when :bgra
            bytes << blue_byte(pixel) << green_byte(pixel) << red_byte(pixel) << alpha_byte(pixel)
          end
        end
        bytes
      end

      def unpack_color(pixel)
        ImmutableColor.new(
          red_byte(pixel) / 255.0,
          green_byte(pixel) / 255.0,
          blue_byte(pixel) / 255.0,
          alpha_byte(pixel) / 255.0
        ).freeze
      end

      def pack_bytes(red, green, blue, alpha)
        (alpha << 24) | (red << 16) | (green << 8) | blue
      end

      def alpha_byte(pixel)
        (pixel >> 24) & 0xFF
      end

      def red_byte(pixel)
        (pixel >> 16) & 0xFF
      end

      def green_byte(pixel)
        (pixel >> 8) & 0xFF
      end

      def blue_byte(pixel)
        pixel & 0xFF
      end

      def color_byte(value)
        (value * 255).round.clamp(0, 255)
      end
    end
  end
end
