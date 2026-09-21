# frozen_string_literal: true

module RBGL
  module GUI
    class FileBackend
      class PngWriter < FrameWriter
        def extension
          "png"
        end

        def write(filename, framebuffer)
          image = Tessel::Image.from_rgba(framebuffer.width, framebuffer.height, framebuffer.to_rgba_bytes)
          image.write(filename)
        end
      end
    end
  end
end
