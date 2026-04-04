# frozen_string_literal: true

module RBGL
  module Engine
    class DynamicData
      def initialize(data = {})
        @data = {}
        data.to_h.each { |key, value| self[key] = value }
      end

      def method_missing(name, *args)
        if writer_method?(name)
          self[writer_key(name)] = args.first
        elsif args.empty? && @data.key?(normalize_key(name))
          self[name]
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        writer_method?(name) || @data.key?(normalize_key(name)) || super
      end

      def [](key)
        @data[normalize_key(key)]
      end

      def []=(key, value)
        @data[normalize_key(key)] = value
      end

      def to_h
        @data.dup
      end

      def keys
        @data.keys
      end

      private

      def normalize_key(key)
        key.to_s.chomp("=").to_sym
      end

      def writer_method?(name)
        name.to_s.end_with?("=")
      end

      def writer_key(name)
        name.to_s.chomp("=").to_sym
      end
    end

    class ShaderIO < DynamicData
    end

    class Uniforms < DynamicData
      def merge(other)
        Uniforms.new(@data.merge(other.to_h))
      end
    end

    module ShaderBuiltins
      def vec2(x, y = nil)
        y ||= x
        Larb::Vec2.new(x, y)
      end

      def vec3(x, y = nil, z = nil)
        if y.nil? && z.nil?
          Larb::Vec3.new(x, x, x)
        elsif z.nil? && y.is_a?(Larb::Vec2)
          Larb::Vec3.new(x, y.x, y.y)
        else
          Larb::Vec3.new(x, y, z)
        end
      end

      def vec4(x, y = nil, z = nil, w = nil)
        case
        when y.nil? && z.nil? && w.nil?
          Larb::Vec4.new(x, x, x, x)
        when x.is_a?(Larb::Vec3) && !y.nil?
          Larb::Vec4.new(x.x, x.y, x.z, y)
        when x.is_a?(Larb::Vec2) && y.is_a?(Larb::Vec2)
          Larb::Vec4.new(x.x, x.y, y.x, y.y)
        else
          Larb::Vec4.new(x, y, z, w)
        end
      end

      def dot(a, b)
        a.dot(b)
      end

      def cross(a, b)
        a.cross(b)
      end

      def normalize(v)
        v.normalize
      end

      def length(v)
        v.length
      end

      def reflect(v, n)
        v.reflect(n)
      end

      def refract(v, n, eta)
        cos_i = -dot(n, v)
        sin_t2 = eta * eta * (1.0 - cos_i * cos_i)
        return vec3(0) if sin_t2 > 1.0

        cos_t = Math.sqrt(1.0 - sin_t2)
        v * eta + n * (eta * cos_i - cos_t)
      end

      def mix(a, b, t)
        case a
        when Numeric then a + (b - a) * t
        when Larb::Vec2, Larb::Vec3, Larb::Vec4 then a.lerp(b, t)
        when Larb::Color then a.lerp(b, t)
        end
      end
      alias lerp mix

      def clamp(v, min_val, max_val)
        case v
        when Numeric then v.clamp(min_val, max_val)
        when Larb::Color then v.clamp
        else
          component_map(v) { |component| component.clamp(min_val, max_val) }
        end
      end

      def saturate(v)
        clamp(v, 0.0, 1.0)
      end

      def smoothstep(edge0, edge1, x)
        component_ternary_map(edge0, edge1, x) do |e0, e1, value|
          t = ((value - e0) / (e1 - e0)).clamp(0.0, 1.0)
          t * t * (3.0 - 2.0 * t)
        end
      end

      def step(edge, x)
        component_binary_map(edge, x) { |limit, value| value < limit ? 0.0 : 1.0 }
      end

      def fract(x)
        component_map(x) { |value| value - value.floor }
      end

      def mod(x, y)
        component_binary_map(x, y) { |left, right| left - right * (left / right).floor }
      end

      def abs(x)
        component_map(x, &:abs)
      end

      def sign(x)
        component_map(x) { |value| value <=> 0 }
      end

      def floor(x)
        component_map(x, &:floor)
      end

      def ceil(x)
        component_map(x, &:ceil)
      end

      def pow(x, y)
        component_binary_map(x, y) { |left, right| left**right }
      end

      def sqrt(x)
        component_map(x) { |value| Math.sqrt(value) }
      end

      def sin(x)
        component_map(x) { |value| Math.sin(value) }
      end

      def cos(x)
        component_map(x) { |value| Math.cos(value) }
      end

      def tan(x)
        component_map(x) { |value| Math.tan(value) }
      end

      def asin(x)
        component_map(x) { |value| Math.asin(value) }
      end

      def acos(x)
        component_map(x) { |value| Math.acos(value) }
      end

      def atan(y, x = nil)
        if x
          component_binary_map(y, x) { |left, right| Math.atan2(left, right) }
        else
          component_map(y) { |value| Math.atan(value) }
        end
      end

      def min(*args)
        values = args.flatten
        return values.min unless values.any? { |value| vector_value?(value) }

        values.reduce { |current, value| component_binary_map(current, value) { |left, right| [left, right].min } }
      end

      def max(*args)
        values = args.flatten
        return values.max unless values.any? { |value| vector_value?(value) }

        values.reduce { |current, value| component_binary_map(current, value) { |left, right| [left, right].max } }
      end

      def texture(tex, uv)
        tex.sample(uv.x, uv.y)
      end

      def texture_lod(tex, uv, lod)
        tex.sample(uv.x, uv.y, lod: lod)
      end

      def rgb(r, g, b)
        Larb::Color.rgb(r, g, b)
      end

      def rgba(r, g, b, a)
        Larb::Color.rgba(r, g, b, a)
      end

      def color_from_vec3(v)
        Larb::Color.from_vec3(v)
      end

      def color_from_vec4(v)
        Larb::Color.from_vec4(v)
      end

      private

      def component_map(value)
        return yield(value) unless vector_value?(value)

        rebuild_vector(value, vector_components(value).map { |component| yield(component) })
      end

      def component_binary_map(left, right)
        return yield(left, right) unless vector_value?(left) || vector_value?(right)

        template = left if vector_value?(left)
        template ||= right

        rebuilt_components = vector_components(template).each_index.map do |index|
          yield(component_at(left, index), component_at(right, index))
        end

        rebuild_vector(template, rebuilt_components)
      end

      def component_ternary_map(first, second, third)
        return yield(first, second, third) unless [first, second, third].any? { |value| vector_value?(value) }

        template = [first, second, third].find { |value| vector_value?(value) }
        rebuilt_components = vector_components(template).each_index.map do |index|
          yield(component_at(first, index), component_at(second, index), component_at(third, index))
        end

        rebuild_vector(template, rebuilt_components)
      end

      def vector_value?(value)
        value.is_a?(Larb::Vec2) || value.is_a?(Larb::Vec3) || value.is_a?(Larb::Vec4)
      end

      def vector_components(value)
        case value
        when Larb::Vec2 then [value.x, value.y]
        when Larb::Vec3 then [value.x, value.y, value.z]
        when Larb::Vec4 then [value.x, value.y, value.z, value.w]
        else
          []
        end
      end

      def component_at(value, index)
        return value unless vector_value?(value)

        vector_components(value)[index]
      end

      def rebuild_vector(template, components)
        case template
        when Larb::Vec2 then Larb::Vec2.new(*components)
        when Larb::Vec3 then Larb::Vec3.new(*components)
        when Larb::Vec4 then Larb::Vec4.new(*components)
        end
      end
    end

    class BaseShader
      include ShaderBuiltins

      def initialize(&block)
        @process_block = block
      end

      def process(input, uniforms)
        output = ShaderIO.new
        @input = input
        @uniforms = uniforms
        @output = output

        instance_exec(input, uniforms, output, &@process_block)
        finalize_output(output)
      end

      attr_reader :input, :uniforms, :output

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

    private_constant :DynamicData
  end
end
