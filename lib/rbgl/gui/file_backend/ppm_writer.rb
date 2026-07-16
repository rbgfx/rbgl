# frozen_string_literal: true

module RBGL
  module GUI
    class FileBackend < Backend
      class PpmWriter < FrameWriter
        def initialize(binary:)
          super()
          @binary = binary
        end

        def extension
          "ppm"
        end

        def write(filename, framebuffer)
          if @binary
            File.binwrite(filename, framebuffer.to_ppm_binary)
          else
            File.write(filename, framebuffer.to_ppm)
          end
        end
      end
    end
  end
end
