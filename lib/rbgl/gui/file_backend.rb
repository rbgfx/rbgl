# frozen_string_literal: true

require "fileutils"
require_relative "file_backend/frame_writer"
require_relative "file_backend/ppm_writer"
require_relative "file_backend/bmp_writer"

module RBGL
  module GUI
    class FileBackend < Backend
      SUPPORTED_FORMATS = %i[ppm bmp].freeze
      PPM_MODES = %i[ascii binary].freeze

      attr_reader :max_frames, :output_dir

      def initialize(width, height, title = "RBGL", format: :ppm, ppm_mode: :ascii, output_dir: ".", max_frames: 1)
        super(width, height, title)
        @format = normalize_format(format)
        @ppm_mode = normalize_ppm_mode(ppm_mode, @format)
        @writer = FrameWriter.build(@format, ppm_mode: @ppm_mode)
        @output_dir = File.expand_path(output_dir)
        FileUtils.mkdir_p(@output_dir)
        @frame_count = 0
        @should_close = false
        self.max_frames = max_frames
      end

      def present(framebuffer)
        filename = File.join(@output_dir, format("frame_%05d.#{@writer.extension}", @frame_count))
        @writer.write(filename, framebuffer)

        @frame_count += 1

        @should_close = true if @max_frames && @frame_count >= @max_frames
        true
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

      def max_frames=(count)
        @max_frames = normalize_max_frames(count)
      end

      alias set_max_frames max_frames=

      private

      def normalize_format(format)
        normalized = format.to_sym
        return normalized if SUPPORTED_FORMATS.include?(normalized)

        raise ArgumentError, "Unsupported file backend format: #{format}"
      end

      def normalize_ppm_mode(ppm_mode, format)
        normalized = ppm_mode.to_sym
        raise ArgumentError, "Unsupported PPM mode: #{ppm_mode}" unless PPM_MODES.include?(normalized)
        return normalized if format == :ppm || normalized == :ascii

        raise ArgumentError, "PPM mode is only supported with :ppm format"
      end

      def normalize_max_frames(count)
        return nil if count.nil?

        normalized = Integer(count)
        return normalized if normalized.positive?

        raise ArgumentError, "max_frames must be a positive integer or nil"
      rescue TypeError
        raise ArgumentError, "max_frames must be a positive integer or nil"
      end
    end
  end
end
