# frozen_string_literal: true

module RBGL
  module Engine
    class BaseShader
      include ShaderBuiltins

      def initialize(&block)
        @process_block = block
      end

      def process(input, uniforms)
        output = ShaderIO.new

        instance_exec(input, uniforms, output, &@process_block)
        finalize_output(output)
      end

      def self.create(&block)
        new(&block)
      end

      private

      def finalize_output(output)
        output
      end
    end

    class VertexShader < BaseShader
      private

      def finalize_output(output)
        raise "VertexShader must set output.position" unless output[:position]

        output
      end
    end

    class FragmentShader < BaseShader
      private

      def finalize_output(output)
        output[:color] ||= Larb::Color.white

        output
      end
    end
  end
end
