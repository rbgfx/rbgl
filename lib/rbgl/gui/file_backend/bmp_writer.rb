# frozen_string_literal: true

module RBGL
  module GUI
    class FileBackend < Backend
      class BmpWriter < FrameWriter
        def extension
          "bmp"
        end

        def write(filename, framebuffer)
          File.binwrite(filename, encode(framebuffer))
        end

        private

        def encode(framebuffer)
          width = framebuffer.width
          height = framebuffer.height
          row_size = ((24 * width + 31) / 32) * 4
          pixel_data_size = row_size * height
          file_size = 54 + pixel_data_size

          header = [
            0x42, 0x4D,
            file_size,
            0, 0,
            54
          ].pack("CCVvvV")

          dib = [
            40,
            width, height,
            1,
            24,
            0,
            pixel_data_size,
            2835, 2835,
            0, 0
          ].pack("VVVvvVVVVVV")

          header + dib + pixel_rows(framebuffer, width, height, row_size)
        end

        def pixel_rows(framebuffer, width, height, row_size)
          pixels = +""

          (height - 1).downto(0) do |y|
            row = +""
            width.times do |x|
              bytes = framebuffer.get_pixel(x, y).to_bytes
              row << [bytes[2], bytes[1], bytes[0]].pack("CCC")
            end
            row << "\x00" * (row_size - width * 3)
            pixels << row
          end

          pixels
        end
      end
    end
  end
end
