# frozen_string_literal: true

module RBGL
  module GUI
    class FileBackend < Backend
      class FrameWriter
        def self.build(format)
          case format
          when :ppm
            PpmWriter.new(binary: false)
          when :ppm_binary
            PpmWriter.new(binary: true)
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
