# frozen_string_literal: true

module RBGL
  module Engine
    class Framebuffer
      attr_reader :width, :height, :color_buffer, :depth_buffer

      def initialize(width, height)
        @width = width
        @height = height
        @color_buffer = Array.new(width * height) { Larb::Color.black }
        @depth_buffer = Array.new(width * height) { Float::INFINITY }
      end

      def get_pixel(x, y)
        return nil if x < 0 || x >= @width || y < 0 || y >= @height

        @color_buffer[y * @width + x]
      end

      def set_pixel(x, y, color)
        return if x < 0 || x >= @width || y < 0 || y >= @height

        @color_buffer[y * @width + x] = color
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

        @color_buffer[idx] = blend_color(@color_buffer[idx], color, blend_mode)
        @depth_buffer[idx] = depth if depth_write
        true
      end

      def clear(color: Larb::Color.black, depth: Float::INFINITY)
        @color_buffer.fill(color)
        @depth_buffer.fill(depth)
      end

      def clear_color(color)
        @color_buffer.fill(color)
      end

      def clear_depth(depth = Float::INFINITY)
        @depth_buffer.fill(depth)
      end

      def to_ppm
        ppm = "P3\n#{@width} #{@height}\n255\n"
        @height.times do |y|
          row = @width.times.map do |x|
            c = @color_buffer[y * @width + x]
            bytes = c.to_bytes
            "#{bytes[0]} #{bytes[1]} #{bytes[2]}"
          end
          ppm += row.join(" ") + "\n"
        end
        ppm
      end

      def to_ppm_binary
        header = "P6\n#{@width} #{@height}\n255\n"
        pixels = @color_buffer.flat_map { |c| c.to_bytes[0..2] }.pack("C*")
        header + pixels
      end

      def to_rgba_bytes
        size = @color_buffer.size
        bytes = Array.new(size * 4)
        i = 0
        size.times do |idx|
          c = @color_buffer[idx]
          bytes[i] = (c.r * 255).round.clamp(0, 255)
          bytes[i + 1] = (c.g * 255).round.clamp(0, 255)
          bytes[i + 2] = (c.b * 255).round.clamp(0, 255)
          bytes[i + 3] = (c.a * 255).round.clamp(0, 255)
          i += 4
        end
        bytes.pack("C*")
      end

      def to_bgra_bytes
        size = @color_buffer.size
        bytes = Array.new(size * 4)
        i = 0
        size.times do |idx|
          c = @color_buffer[idx]
          bytes[i] = (c.b * 255).round.clamp(0, 255)
          bytes[i + 1] = (c.g * 255).round.clamp(0, 255)
          bytes[i + 2] = (c.r * 255).round.clamp(0, 255)
          bytes[i + 3] = (c.a * 255).round.clamp(0, 255)
          i += 4
        end
        bytes.pack("C*")
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
    end
  end
end
