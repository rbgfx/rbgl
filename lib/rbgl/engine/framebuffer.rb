# frozen_string_literal: true

module RBGL
  module Engine
    class Framebuffer
      attr_reader :width, :height, :color_buffer, :depth_buffer

      def initialize(width, height)
        @width = width
        @height = height
        @color_buffer = color_buffer_filled_with(Larb::Color.black)
        @depth_buffer = Array.new(width * height) { Float::INFINITY }
      end

      def resize(width, height)
        @width = width
        @height = height
        @color_buffer = color_buffer_filled_with(Larb::Color.black)
        @depth_buffer = Array.new(width * height) { Float::INFINITY }
      end

      def get_pixel(x, y)
        return nil if x < 0 || x >= @width || y < 0 || y >= @height

        @color_buffer[y * @width + x]
      end

      def set_pixel(x, y, color)
        return if x < 0 || x >= @width || y < 0 || y >= @height

        @color_buffer[y * @width + x] = immutable_color(color)
      end

      def get_depth(x, y)
        return Float::INFINITY if x < 0 || x >= @width || y < 0 || y >= @height

        @depth_buffer[y * @width + x]
      end

      def set_depth(x, y, depth)
        return if x < 0 || x >= @width || y < 0 || y >= @height

        @depth_buffer[y * @width + x] = depth
      end

      def write_pixel(x, y, color, depth, depth_test: true, depth_write: true, blend_mode: :none)
        return false if x < 0 || x >= @width || y < 0 || y >= @height

        idx = y * @width + x
        return false if depth_test && depth >= @depth_buffer[idx]

        @color_buffer[idx] = immutable_color(blend_color(@color_buffer[idx], color, blend_mode))
        @depth_buffer[idx] = depth if depth_write
        true
      end

      def clear(color: Larb::Color.black, depth: Float::INFINITY)
        @color_buffer.fill(immutable_color(color))
        @depth_buffer.fill(depth)
      end

      def clear_color(color)
        @color_buffer.fill(immutable_color(color))
      end

      def clear_depth(depth = Float::INFINITY)
        @depth_buffer.fill(depth)
      end

      def to_ppm
        ppm = String.new(capacity: @width * @height * 12, encoding: Encoding::BINARY)
        ppm << "P3\n#{@width} #{@height}\n255\n"
        @height.times do |y|
          @width.times do |x|
            c = @color_buffer[y * @width + x]
            ppm << " " unless x.zero?
            ppm << color_byte(c.r).to_s << " " << color_byte(c.g).to_s << " " << color_byte(c.b).to_s
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

      def blend_color(destination, source, blend_mode)
        case blend_mode
        when :alpha
          alpha = source.a
          inv_alpha = 1.0 - alpha
          Larb::Color.new(
            source.r * alpha + destination.r * inv_alpha,
            source.g * alpha + destination.g * inv_alpha,
            source.b * alpha + destination.b * inv_alpha,
            alpha + destination.a * inv_alpha
          )
        else
          source
        end
      end

      def immutable_color(color)
        ImmutableColor.from(color)
      end

      def color_buffer_filled_with(color)
        Array.new(@width * @height, immutable_color(color))
      end

      def packed_color_bytes(format)
        channel_count = format == :rgb ? 3 : 4
        bytes = String.new(capacity: @color_buffer.length * channel_count, encoding: Encoding::BINARY)

        @color_buffer.each do |color|
          case format
          when :rgb
            bytes << color_byte(color.r) << color_byte(color.g) << color_byte(color.b)
          when :rgba
            bytes << color_byte(color.r) << color_byte(color.g) << color_byte(color.b) << color_byte(color.a)
          when :bgra
            bytes << color_byte(color.b) << color_byte(color.g) << color_byte(color.r) << color_byte(color.a)
          end
        end
        bytes
      end

      def color_byte(value)
        (value * 255).round.clamp(0, 255)
      end
    end
  end
end
