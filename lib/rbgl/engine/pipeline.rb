# frozen_string_literal: true

module RBGL
  module Engine
    class Pipeline
      VALID_CULL_MODES = %i[none front back].freeze
      VALID_BLEND_MODES = %i[none alpha].freeze

      attr_accessor :vertex_shader, :fragment_shader
      attr_reader :depth_test, :depth_write, :cull_mode, :blend_mode

      def initialize
        @vertex_shader = nil
        @fragment_shader = nil
        self.depth_test = true
        self.depth_write = true
        self.cull_mode = :back
        self.blend_mode = :none
      end

      def self.create(&block)
        pipeline = new
        pipeline.instance_eval(&block) if block_given?
        pipeline
      end

      def vertex(&block)
        @vertex_shader = VertexShader.new(&block)
      end

      def fragment(&block)
        @fragment_shader = FragmentShader.new(&block)
      end

      def depth_test=(value)
        @depth_test = validate_boolean!(:depth_test, value)
      end

      def depth_write=(value)
        @depth_write = validate_boolean!(:depth_write, value)
      end

      def cull_mode=(value)
        @cull_mode = validate_enum!(:cull_mode, value, VALID_CULL_MODES)
      end

      def blend_mode=(value)
        @blend_mode = validate_enum!(:blend_mode, value, VALID_BLEND_MODES)
      end

      private

      def validate_boolean!(name, value)
        return value if value == true || value == false

        raise ArgumentError, "#{name} must be true or false"
      end

      def validate_enum!(name, value, allowed_values)
        return value if allowed_values.include?(value)

        raise ArgumentError, "#{name} must be one of: #{allowed_values.join(', ')}"
      end
    end
  end
end
