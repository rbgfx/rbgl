# frozen_string_literal: true

module RBGL
  module Engine
    class Rasterizer
      class TriangleRenderer
        def initialize(framebuffer, interpolator:, viewport_transform:, edge_function:)
          @framebuffer = framebuffer
          @interpolator = interpolator
          @viewport_transform = viewport_transform
          @edge_function = edge_function
        end

        def rasterize(v0, v1, v2, fragment_shader, uniforms, state)
          p0 = @viewport_transform.call(v0[:position])
          p1 = @viewport_transform.call(v1[:position])
          p2 = @viewport_transform.call(v2[:position])

          area = @edge_function.call(p0, p1, p2)
          return if area.abs < 1e-10
          return if culled?(area, state[:cull_mode])

          min_x, max_x, min_y, max_y = bounds(p0, p1, p2)
          inv_area = 1.0 / area

          (min_y..max_y).each do |y|
            (min_x..max_x).each do |x|
              weights = barycentric_weights(p0, p1, p2, x + 0.5, y + 0.5)
              next unless inside_triangle?(weights)

              screen_weights = weights.map { |weight| weight * inv_area }
              corrected_weights = @interpolator.perspective_correct_weights(
                [v0[:position], v1[:position], v2[:position]],
                screen_weights
              )
              depth = @interpolator.interpolate_depth([p0.z, p1.z, p2.z], corrected_weights)
              attributes = @interpolator.interpolate([v0, v1, v2], corrected_weights)

              shade_fragment(x, y, depth, attributes, fragment_shader, uniforms, state)
            end
          end
        end

        private

        def bounds(p0, p1, p2)
          min_x = [p0.x, p1.x, p2.x].min.floor.clamp(0, @framebuffer.width - 1)
          max_x = [p0.x, p1.x, p2.x].max.ceil.clamp(0, @framebuffer.width - 1)
          min_y = [p0.y, p1.y, p2.y].min.floor.clamp(0, @framebuffer.height - 1)
          max_y = [p0.y, p1.y, p2.y].max.ceil.clamp(0, @framebuffer.height - 1)
          [min_x, max_x, min_y, max_y]
        end

        def barycentric_weights(p0, p1, p2, x, y)
          point = Larb::Vec2.new(x, y)
          [
            @edge_function.call(p1, p2, point),
            @edge_function.call(p2, p0, point),
            @edge_function.call(p0, p1, point)
          ]
        end

        def inside_triangle?(weights)
          weights.all? { |weight| weight >= 0 } || weights.all? { |weight| weight <= 0 }
        end

        def culled?(area, cull_mode)
          case cull_mode
          when :back then area < 0
          when :front then area > 0
          else false
          end
        end

        def shade_fragment(x, y, depth, attributes, fragment_shader, uniforms, state)
          frag_output = fragment_shader.process(attributes, uniforms)
          @framebuffer.write_pixel(
            x, y, frag_output[:color], depth,
            depth_test: state[:depth_test],
            depth_write: state[:depth_write],
            blend_mode: state[:blend_mode]
          )
        end
      end
    end
  end
end
