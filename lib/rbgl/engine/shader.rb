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
        elsif args.empty?
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
        when Larb::Vec3
          Larb::Vec3.new(
            v.x.clamp(min_val, max_val),
            v.y.clamp(min_val, max_val),
            v.z.clamp(min_val, max_val)
          )
        when Larb::Color then v.clamp
        end
      end

      def saturate(v)
        clamp(v, 0.0, 1.0)
      end

      def smoothstep(edge0, edge1, x)
        t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0)
        t * t * (3.0 - 2.0 * t)
      end

      def step(edge, x)
        x < edge ? 0.0 : 1.0
      end

      def fract(x)
        x - x.floor
      end

      def mod(x, y)
        x - y * (x / y).floor
      end

      def abs(x)
        case x
        when Numeric then x.abs
        when Larb::Vec3 then Larb::Vec3.new(x.x.abs, x.y.abs, x.z.abs)
        end
      end

      def sign(x)
        x <=> 0
      end

      def floor(x)
        case x
        when Numeric then x.floor
        when Larb::Vec3 then Larb::Vec3.new(x.x.floor, x.y.floor, x.z.floor)
        end
      end

      def ceil(x)
        case x
        when Numeric then x.ceil
        when Larb::Vec3 then Larb::Vec3.new(x.x.ceil, x.y.ceil, x.z.ceil)
        end
      end

      def pow(x, y)
        case x
        when Numeric then x**y
        when Larb::Vec3 then Larb::Vec3.new(x.x**y, x.y**y, x.z**y)
        end
      end

      def sqrt(x)
        case x
        when Numeric then Math.sqrt(x)
        when Larb::Vec3 then Larb::Vec3.new(Math.sqrt(x.x), Math.sqrt(x.y), Math.sqrt(x.z))
        end
      end

      def sin(x)
        Math.sin(x)
      end

      def cos(x)
        Math.cos(x)
      end

      def tan(x)
        Math.tan(x)
      end

      def asin(x)
        Math.asin(x)
      end

      def acos(x)
        Math.acos(x)
      end

      def atan(y, x = nil)
        x ? Math.atan2(y, x) : Math.atan(y)
      end

      def min(*args)
        args.flatten.min
      end

      def max(*args)
        args.flatten.max
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
