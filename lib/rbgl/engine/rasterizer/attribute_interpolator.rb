# frozen_string_literal: true

module RBGL
  module Engine
    class Rasterizer
      class AttributeInterpolator
        def interpolate(vertices, weights)
          result = ShaderIO.new

          interpolated_keys(vertices).each do |key|
            values = vertices.map { |vertex| vertex[key] }
            next if values.any?(&:nil?)

            result[key] = interpolate_values(values, weights)
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

        private

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

        def inverse_clip_w(position)
          return 1.0 unless position.is_a?(Larb::Vec4)
          return 1.0 if position.w.zero?

          1.0 / position.w
        end
      end
    end
  end
end
