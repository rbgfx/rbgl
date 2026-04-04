# frozen_string_literal: true

require_relative "file_backend/frame_writer"
require_relative "file_backend/ppm_writer"
require_relative "file_backend/bmp_writer"

module RBGL
  module GUI
    class FileBackend < Backend
      SUPPORTED_FORMATS = %i[ppm ppm_binary bmp].freeze

      def initialize(width, height, title = "RBGL", format: :ppm, output_dir: ".")
        super(width, height, title)
        @format = normalize_format(format)
        @writer = FrameWriter.build(@format)
        @output_dir = output_dir
        @frame_count = 0
        @should_close = false
        @max_frames = nil
      end

      def present(framebuffer)
        filename = File.join(@output_dir, format("frame_%05d.#{@writer.extension}", @frame_count))
        @writer.write(filename, framebuffer)

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
    end
  end
end
