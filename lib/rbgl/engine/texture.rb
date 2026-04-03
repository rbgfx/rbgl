# frozen_string_literal: true

module RBGL
  module Engine
    class Texture
      attr_reader :width, :height, :data
      attr_accessor :wrap_s, :wrap_t, :filter_min, :filter_mag

      WRAP_REPEAT = :repeat
      WRAP_CLAMP = :clamp
      WRAP_MIRROR = :mirror

      FILTER_NEAREST = :nearest
      FILTER_LINEAR = :linear

      def initialize(width, height, data = nil)
        @width = width
        @height = height
        @data = data || Array.new(width * height) { Larb::Color.black }
        @wrap_s = WRAP_REPEAT
        @wrap_t = WRAP_REPEAT
        @filter_min = FILTER_LINEAR
        @filter_mag = FILTER_LINEAR
      end

      def sample(u, v, lod: 0)
        u = wrap_coord(u, @wrap_s)
        v = wrap_coord(v, @wrap_t)

        x = u * (@width - 1)
        y = v * (@height - 1)

        sample_with_filter(x, y, filter_for_lod(lod))
      end

      def get_pixel(x, y)
        x = x.clamp(0, @width - 1).to_i
        y = y.clamp(0, @height - 1).to_i
        @data[y * @width + x]
      end

      def set_pixel(x, y, color)
        return if x < 0 || x >= @width || y < 0 || y >= @height

        @data[y.to_i * @width + x.to_i] = color
      end

      def self.from_ppm(filename)
        content = File.read(filename, mode: "rb")
        lines = content.lines.reject { |l| l.start_with?("#") }

        _format = lines.shift.strip
        dimensions = lines.shift.strip.split.map(&:to_i)
        width, height = dimensions
        max_val = lines.shift.strip.to_i

        data = []
        pixels = lines.join.split.map(&:to_i)
        (pixels.size / 3).times do |i|
          r = pixels[i * 3] / max_val.to_f
          g = pixels[i * 3 + 1] / max_val.to_f
          b = pixels[i * 3 + 2] / max_val.to_f
          data << Larb::Color.rgb(r, g, b)
        end

        new(width, height, data)
      end

      def self.checker(width, height, size, color1 = Larb::Color.white, color2 = Larb::Color.black)
        data = Array.new(width * height)
        height.times do |y|
          width.times do |x|
            checker = ((x / size) + (y / size)) % 2
            data[y * width + x] = checker == 0 ? color1 : color2
          end
        end
        new(width, height, data)
      end

      def self.solid(width, height, color)
        new(width, height, Array.new(width * height) { color })
      end

      private

      def wrap_coord(coord, mode)
        case mode
        when WRAP_REPEAT
          coord - coord.floor
        when WRAP_CLAMP
          coord.clamp(0.0, 1.0)
        when WRAP_MIRROR
          t = coord - coord.floor
          coord.floor.to_i.even? ? t : 1.0 - t
        end
      end

      def sample_nearest(x, y)
        get_pixel(x.round, y.round)
      end

      def filter_for_lod(lod)
        lod.to_f.positive? ? @filter_min : @filter_mag
      end

      def sample_with_filter(x, y, filter)
        case filter
        when FILTER_NEAREST
          sample_nearest(x, y)
        else
          sample_bilinear(x, y)
        end
      end

      def sample_bilinear(x, y)
        x0 = x.floor.to_i
        y0 = y.floor.to_i
        x1 = x0 + 1
        y1 = y0 + 1
        fx = x - x0
        fy = y - y0

        c00 = get_pixel(x0, y0)
        c10 = get_pixel(x1, y0)
        c01 = get_pixel(x0, y1)
        c11 = get_pixel(x1, y1)

        c0 = c00.lerp(c10, fx)
        c1 = c01.lerp(c11, fx)
        c0.lerp(c1, fy)
      end
    end
  end
end
