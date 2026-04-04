# frozen_string_literal: true

module RBGL
  module Engine
    class Rasterizer
      class LineRenderer
        def initialize(framebuffer, interpolator:, viewport_transform:)
          @framebuffer = framebuffer
          @interpolator = interpolator
          @viewport_transform = viewport_transform
        end

        def rasterize(v0, v1, fragment_shader, uniforms, state)
          p0 = @viewport_transform.call(v0[:position])
          p1 = @viewport_transform.call(v1[:position])

          x0 = p0.x.round
          y0 = p0.y.round
          x1 = p1.x.round
          y1 = p1.y.round

          dx = (x1 - x0).abs
          dy = -(y1 - y0).abs
          sx = x0 < x1 ? 1 : -1
          sy = y0 < y1 ? 1 : -1
          err = dx + dy
          total_dist = Math.sqrt((x1 - x0)**2 + (y1 - y0)**2)

          loop do
            t = interpolation_factor(x0, y0, p0, total_dist)
            corrected_weights = @interpolator.perspective_correct_weights(
              [v0[:position], v1[:position]],
              [1.0 - t, t]
            )
            depth = @interpolator.interpolate_depth([p0.z, p1.z], corrected_weights)
            attributes = @interpolator.interpolate([v0, v1], corrected_weights)

            shade_fragment(x0, y0, depth, attributes, fragment_shader, uniforms, state)
            break if x0 == x1 && y0 == y1

            e2 = 2 * err
            if e2 >= dy
              err += dy
              x0 += sx
            end
            if e2 <= dx
              err += dx
              y0 += sy
            end
          end
        end

        private

        def interpolation_factor(x, y, start_point, total_dist)
          current_dist = Math.sqrt((x - start_point.x.round)**2 + (y - start_point.y.round)**2)
          total_dist.positive? ? current_dist / total_dist : 0.0
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
