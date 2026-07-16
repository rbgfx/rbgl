# frozen_string_literal: true

module RBGL
  module Engine
    class Texture
      PPM_HEADER = /\A(P[36])(?:\s+|#[^\n]*\n)+(\d+)(?:\s+|#[^\n]*\n)+(\d+)(?:\s+|#[^\n]*\n)+(\d+)\s/m
      WRAP_MODES = %i[repeat clamp mirror].freeze
      FILTER_MODES = %i[nearest linear].freeze

      attr_reader :width, :height, :data, :wrap_s, :wrap_t, :filter_min, :filter_mag

      WRAP_REPEAT = :repeat
      WRAP_CLAMP = :clamp
      WRAP_MIRROR = :mirror

      FILTER_NEAREST = :nearest
      FILTER_LINEAR = :linear

      def initialize(width, height, data = nil)
        @width = width
        @height = height
        @data = data ? normalize_data!(data) : Array.new(width * height, immutable_color(Larb::Color.black))
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

        @data[(y.to_i * @width) + x.to_i] = immutable_color(color)
        @mipmaps_dirty = true
      end

      def generate_mipmaps!
        rebuild_mipmap_chain!
        self
      end

      def wrap_s=(mode)
        @wrap_s = validate_wrap_mode!(mode)
      end

      def wrap_t=(mode)
        @wrap_t = validate_wrap_mode!(mode)
      end

      def filter_min=(filter)
        @filter_min = validate_filter_mode!(filter)
      end

      def filter_mag=(filter)
        @filter_mag = validate_filter_mode!(filter)
      end

      def self.from_ppm(filename)
        content = File.binread(filename)
        format, width, height, max_val, body_offset = parse_ppm_header(content)
        samples = parse_ppm_samples(content, format, width * height, max_val, body_offset)

        new(width, height, colors_from_ppm_samples(samples, max_val))
      end

      def self.checker(width, height, size, color1 = Larb::Color.white, color2 = Larb::Color.black)
        data = Array.new(width * height)
        height.times do |y|
          width.times do |x|
            checker = ((x / size) + (y / size)) % 2
            data[(y * width) + x] = checker == 0 ? color1 : color2
          end
        end
        new(width, height, data)
      end

      def self.solid(width, height, color)
        immutable = ImmutableColor.from(color)
        new(width, height, Array.new(width * height, immutable))
      end

      def self.parse_ppm_header(content)
        match = PPM_HEADER.match(content)
        raise ArgumentError, "Invalid PPM header" unless match

        format = match[1]
        width = match[2].to_i
        height = match[3].to_i
        max_val = match[4].to_i
        raise ArgumentError, "Unsupported PPM max value: #{max_val}" unless max_val.between?(1, 65_535)

        [format, width, height, max_val, match.end(0)]
      end

      def self.parse_ppm_samples(content, format, pixel_count, max_val, body_offset)
        case format
        when "P3"
          parse_p3_samples(content.byteslice(body_offset..), pixel_count)
        when "P6"
          parse_p6_samples(content, body_offset, pixel_count, max_val)
        else
          raise ArgumentError, "Unsupported PPM format: #{format}"
        end
      end

      def self.parse_p3_samples(body, pixel_count)
        samples = body.to_s.gsub(/#[^\n]*/, " ").scan(/\d+/).map(&:to_i)
        expected_count = pixel_count * 3
        raise ArgumentError, "PPM pixel data is truncated" if samples.length < expected_count

        samples.first(expected_count)
      end

      def self.parse_p6_samples(content, body_offset, pixel_count, max_val)
        sample_size = max_val < 256 ? 1 : 2
        expected_bytes = pixel_count * 3 * sample_size
        body = content.byteslice(body_offset, expected_bytes)
        raise ArgumentError, "PPM pixel data is truncated" unless body && body.bytesize == expected_bytes

        if sample_size == 1
          body.bytes
        else
          body.unpack("n*")
        end
      end

      def self.colors_from_ppm_samples(samples, max_val)
        samples.each_slice(3).map do |r, g, b|
          Larb::Color.rgb(r / max_val.to_f, g / max_val.to_f, b / max_val.to_f)
        end
      end

      private_class_method :parse_ppm_header, :parse_ppm_samples, :parse_p3_samples,
                           :parse_p6_samples, :colors_from_ppm_samples

      private

      def normalize_data!(data)
        raise ArgumentError, "Texture data must be convertible to an Array" unless data.respond_to?(:to_a)

        normalized = data.to_a
        expected_size = @width * @height

        unless normalized.size == expected_size
          raise ArgumentError, "Texture data size mismatch: expected #{expected_size}, got #{normalized.size}"
        end

        normalized.map { |pixel| immutable_color(pixel) }
      end

      def validate_color!(color)
        return color if color.is_a?(Larb::Color)

        raise ArgumentError, "Texture data must contain only Larb::Color values"
      end

      def immutable_color(color)
        ImmutableColor.from(validate_color!(color))
      end

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

      def validate_wrap_mode!(mode)
        normalized = mode.to_sym
        return normalized if WRAP_MODES.include?(normalized)

        raise ArgumentError, "Unsupported wrap mode: #{mode}"
      end

      def validate_filter_mode!(mode)
        normalized = mode.to_sym
        return normalized if FILTER_MODES.include?(normalized)

        raise ArgumentError, "Unsupported filter mode: #{mode}"
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
        when FILTER_LINEAR
          sample_bilinear(level, x, y)
        else
          raise ArgumentError, "Unsupported filter mode: #{filter}"
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
        level_data[(clamped_y * level_width) + clamped_x]
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
            samples << source_data[(y * source_width) + x]
          end
        end

        sample_count = samples.length.to_f
        immutable_color(Larb::Color.new(
          samples.sum(&:r) / sample_count,
          samples.sum(&:g) / sample_count,
          samples.sum(&:b) / sample_count,
          samples.sum(&:a) / sample_count
        ))
      end
    end
  end
end
