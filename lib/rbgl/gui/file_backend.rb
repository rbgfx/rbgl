# frozen_string_literal: true

module RBGL
  module GUI
    class FileBackend < Backend
      SUPPORTED_FORMATS = %i[ppm ppm_binary bmp].freeze

      def initialize(width, height, title = "RBGL", format: :ppm, output_dir: ".")
        super(width, height, title)
        @format = normalize_format(format)
        @output_dir = output_dir
        @frame_count = 0
        @should_close = false
        @max_frames = nil
      end

      def present(framebuffer)
        filename = File.join(@output_dir, format("frame_%05d.#{@format}", @frame_count))
        write_frame(filename, framebuffer)

        @frame_count += 1

        @should_close = true if @max_frames && @frame_count >= @max_frames
      end

      def poll_events
        []
      end

      def should_close?
        @should_close
      end

      def close
        @should_close = true
      end

      def set_max_frames(count)
        @max_frames = count
      end

      private

      def normalize_format(format)
        normalized = format.to_sym
        return normalized if SUPPORTED_FORMATS.include?(normalized)

        raise ArgumentError, "Unsupported file backend format: #{format}"
      end

      def write_frame(filename, framebuffer)
        data, binary = encoded_frame(framebuffer)

        if binary
          File.binwrite(filename, data)
        else
          File.write(filename, data)
        end
      end

      def encoded_frame(framebuffer)
        case @format
        when :ppm
          [framebuffer.to_ppm, false]
        when :ppm_binary
          [framebuffer.to_ppm_binary, true]
        when :bmp
          [to_bmp(framebuffer), true]
        end
      end

      def to_bmp(framebuffer)
        w = framebuffer.width
        h = framebuffer.height
        row_size = ((24 * w + 31) / 32) * 4
        pixel_data_size = row_size * h
        file_size = 54 + pixel_data_size

        header = [
          0x42, 0x4D,
          file_size,
          0, 0,
          54
        ].pack("CCVvvV")

        dib = [
          40,
          w, h,
          1,
          24,
          0,
          pixel_data_size,
          2835, 2835,
          0, 0
        ].pack("VVVvvVVVVVV")

        pixels = +""
        (h - 1).downto(0) do |y|
          row = +""
          w.times do |x|
            color = framebuffer.get_pixel(x, y)
            bytes = color.to_bytes
            row << [bytes[2], bytes[1], bytes[0]].pack("CCC")
          end
          padding = row_size - w * 3
          row << "\x00" * padding
          pixels << row
        end

        header + dib + pixels
      end
    end
  end
end
