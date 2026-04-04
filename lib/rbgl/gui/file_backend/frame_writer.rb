# frozen_string_literal: true

module RBGL
  module GUI
    class FileBackend < Backend
      class FrameWriter
        def self.build(format, ppm_mode: :ascii)
          case format
          when :ppm
            PpmWriter.new(binary: ppm_mode == :binary)
          when :bmp
            BmpWriter.new
          else
            raise ArgumentError, "Unsupported file backend format: #{format}"
          end
        end

        def extension
          raise NotImplementedError
        end

        def write(_filename, _framebuffer)
          raise NotImplementedError
        end
      end
    end
  end
end
