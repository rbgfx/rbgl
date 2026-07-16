# frozen_string_literal: true

module RBGL
  module Engine
    class Rasterizer
      class AttributeInterpolator
        def interpolate(vertices, weights)
          interpolate_prepared(prepare(vertices), weights, result: ShaderIO.new)
        end

        def prepare(vertices)
          interpolated_keys(vertices).filter_map do |key|
            values = vertices.map { |vertex| vertex[key] }
            [key, *values] unless values.any?(&:nil?)
          end
        end

        def interpolate_prepared(plan, weights, result:)
          result.clear
          plan.each do |entry|
            result[entry[0]] = interpolate_values(entry.drop(1), weights)
          end
          result
        end

        def interpolate_triangle(plan, w0, w1, w2, result:)
          result.clear
          plan.each do |key, a, b, c|
            result[key] = interpolate_three(a, b, c, w0, w1, w2)
          end
          result
        end

        def interpolate_line(plan, w0, w1, result:)
          result.clear
          plan.each do |key, a, b|
            result[key] = interpolate_two(a, b, w0, w1)
          end
          result
        end

        def interpolate_values(values, weights)
          first = values.first

          case first
          when Larb::Vec2
            vector2(values, weights)
          when Larb::Vec3
            vector3(values, weights)
          when Larb::Vec4
            vector4(values, weights)
          when Larb::Color
            color(values, weights)
          when Numeric
            scalar(values, weights)
          else
            first
          end
        end

        def interpolate_depth(depths, weights)
          scalar(depths, weights)
        end

        def perspective_correct_weights(positions, weights)
          corrected = positions.zip(weights).map do |position, weight|
            weight * inverse_clip_w(position)
          end
          total = corrected.sum
          return weights if total.zero?

          corrected.map { |weight| weight / total }
        end

        def inverse_clip_w(position)
          return 1.0 unless position.is_a?(Larb::Vec4)
          return 1.0 if position.w.zero?

          1.0 / position.w
        end

        private

        def interpolate_three(a, b, c, w0, w1, w2)
          case a
          when Larb::Vec2
            Larb::Vec2.new(a.x * w0 + b.x * w1 + c.x * w2, a.y * w0 + b.y * w1 + c.y * w2)
          when Larb::Vec3
            Larb::Vec3.new(
              a.x * w0 + b.x * w1 + c.x * w2,
              a.y * w0 + b.y * w1 + c.y * w2,
              a.z * w0 + b.z * w1 + c.z * w2
            )
          when Larb::Vec4
            Larb::Vec4.new(
              a.x * w0 + b.x * w1 + c.x * w2,
              a.y * w0 + b.y * w1 + c.y * w2,
              a.z * w0 + b.z * w1 + c.z * w2,
              a.w * w0 + b.w * w1 + c.w * w2
            )
          when Larb::Color
            Larb::Color.new(
              a.r * w0 + b.r * w1 + c.r * w2,
              a.g * w0 + b.g * w1 + c.g * w2,
              a.b * w0 + b.b * w1 + c.b * w2,
              a.a * w0 + b.a * w1 + c.a * w2
            )
          when Numeric then a * w0 + b * w1 + c * w2
          else a
          end
        end

        def interpolate_two(a, b, w0, w1)
          case a
          when Larb::Vec2
            Larb::Vec2.new(a.x * w0 + b.x * w1, a.y * w0 + b.y * w1)
          when Larb::Vec3
            Larb::Vec3.new(a.x * w0 + b.x * w1, a.y * w0 + b.y * w1, a.z * w0 + b.z * w1)
          when Larb::Vec4
            Larb::Vec4.new(
              a.x * w0 + b.x * w1,
              a.y * w0 + b.y * w1,
              a.z * w0 + b.z * w1,
              a.w * w0 + b.w * w1
            )
          when Larb::Color
            Larb::Color.new(
              a.r * w0 + b.r * w1,
              a.g * w0 + b.g * w1,
              a.b * w0 + b.b * w1,
              a.a * w0 + b.a * w1
            )
          when Numeric then a * w0 + b * w1
          else a
          end
        end

        def interpolated_keys(vertices)
          vertices.flat_map { |vertex| vertex.to_h.keys }.uniq - [:position]
        end

        def scalar(values, weights)
          values.zip(weights).sum { |value, weight| value * weight }
        end

        def vector2(values, weights)
          Larb::Vec2.new(
            scalar(values.map(&:x), weights),
            scalar(values.map(&:y), weights)
          )
        end

        def vector3(values, weights)
          Larb::Vec3.new(
            scalar(values.map(&:x), weights),
            scalar(values.map(&:y), weights),
            scalar(values.map(&:z), weights)
          )
        end

        def vector4(values, weights)
          Larb::Vec4.new(
            scalar(values.map(&:x), weights),
            scalar(values.map(&:y), weights),
            scalar(values.map(&:z), weights),
            scalar(values.map(&:w), weights)
          )
        end

        def color(values, weights)
          Larb::Color.new(
            scalar(values.map(&:r), weights),
            scalar(values.map(&:g), weights),
            scalar(values.map(&:b), weights),
            scalar(values.map(&:a), weights)
          )
        end

      end
    end
  end
end
