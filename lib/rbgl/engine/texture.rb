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
        @levels = [@data]
        @mipmaps_dirty = true
        @wrap_s = WRAP_REPEAT
        @wrap_t = WRAP_REPEAT
        @filter_min = FILTER_LINEAR
        @filter_mag = FILTER_LINEAR
      end

      def sample(u, v, lod: 0)
        u = wrap_coord(u, @wrap_s)
        v = wrap_coord(v, @wrap_t)
        level = mip_level_for(lod)
        level_width = width_for_level(level)
        level_height = height_for_level(level)

        x = u * (level_width - 1)
        y = v * (level_height - 1)

        sample_with_filter(level, x, y, filter_for_lod(lod))
      end

      def get_pixel(x, y)
        pixel_for_level(0, x, y)
      end

      def set_pixel(x, y, color)
        return if x < 0 || x >= @width || y < 0 || y >= @height

        @data[y.to_i * @width + x.to_i] = color
        @mipmaps_dirty = true
      end

      def generate_mipmaps!
        rebuild_mipmap_chain!
        self
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

      def sample_nearest(level, x, y)
        pixel_for_level(level, x.round, y.round)
      end

      def filter_for_lod(lod)
        lod.to_f.positive? ? @filter_min : @filter_mag
      end

      def sample_with_filter(level, x, y, filter)
        case filter
        when FILTER_NEAREST
          sample_nearest(level, x, y)
        else
          sample_bilinear(level, x, y)
        end
      end

      def sample_bilinear(level, x, y)
        x0 = x.floor.to_i
        y0 = y.floor.to_i
        x1 = x0 + 1
        y1 = y0 + 1
        fx = x - x0
        fy = y - y0

        c00 = pixel_for_level(level, x0, y0)
        c10 = pixel_for_level(level, x1, y0)
        c01 = pixel_for_level(level, x0, y1)
        c11 = pixel_for_level(level, x1, y1)

        c0 = c00.lerp(c10, fx)
        c1 = c01.lerp(c11, fx)
        c0.lerp(c1, fy)
      end

      def mip_level_for(lod)
        return 0 unless lod.to_f.positive?

        rebuild_mipmap_chain! if @mipmaps_dirty
        [lod.floor, @levels.size - 1].min
      end

      def pixel_for_level(level, x, y)
        level_width = width_for_level(level)
        level_height = height_for_level(level)
        level_data = level.zero? ? @data : level_data(level)
        clamped_x = x.clamp(0, level_width - 1).to_i
        clamped_y = y.clamp(0, level_height - 1).to_i
        level_data[clamped_y * level_width + clamped_x]
      end

      def level_data(level)
        rebuild_mipmap_chain! if @mipmaps_dirty
        @levels[level] || @data
      end

      def width_for_level(level)
        [@width >> level, 1].max
      end

      def height_for_level(level)
        [@height >> level, 1].max
      end

      def rebuild_mipmap_chain!
        @levels = [@data]

        current_data = @data
        current_width = @width
        current_height = @height

        while current_width > 1 || current_height > 1
          next_width = [current_width / 2, 1].max
          next_height = [current_height / 2, 1].max
          current_data = build_next_level(current_data, current_width, current_height, next_width, next_height)
          @levels << current_data
          current_width = next_width
          current_height = next_height
        end

        @mipmaps_dirty = false
      end

      def build_next_level(source_data, source_width, source_height, target_width, target_height)
        Array.new(target_width * target_height) do |index|
          x = index % target_width
          y = index / target_width
          average_texel_block(source_data, source_width, source_height, x * 2, y * 2)
        end
      end

      def average_texel_block(source_data, source_width, source_height, start_x, start_y)
        samples = []

        2.times do |dy|
          2.times do |dx|
            x = [start_x + dx, source_width - 1].min
            y = [start_y + dy, source_height - 1].min
            samples << source_data[y * source_width + x]
          end
        end

        sample_count = samples.length.to_f
        Larb::Color.new(
          samples.sum(&:r) / sample_count,
          samples.sum(&:g) / sample_count,
          samples.sum(&:b) / sample_count,
          samples.sum(&:a) / sample_count
        )
      end
    end
  end
end
