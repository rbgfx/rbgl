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
          inverse_w0 = @interpolator.inverse_clip_w(v0[:position])
          inverse_w1 = @interpolator.inverse_clip_w(v1[:position])
          interpolation_plan = @interpolator.prepare([v0, v1])
          attributes = ShaderIO.new
          fragment_output = ShaderIO.new

          loop do
            t = interpolation_factor(x0, y0, p0, total_dist)
            corrected_w0 = (1.0 - t) * inverse_w0
            corrected_w1 = t * inverse_w1
            total = corrected_w0 + corrected_w1
            unless total.zero?
              corrected_w0 /= total
              corrected_w1 /= total
            end
            depth = p0.z * corrected_w0 + p1.z * corrected_w1
            @interpolator.interpolate_line(interpolation_plan, corrected_w0, corrected_w1, result: attributes)

            shade_fragment(x0, y0, depth, attributes, fragment_shader, uniforms, state, fragment_output)
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

        def shade_fragment(x, y, depth, attributes, fragment_shader, uniforms, state, fragment_output)
          frag_output = fragment_shader.process(attributes, uniforms, output: fragment_output)
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
