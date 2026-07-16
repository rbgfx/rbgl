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
          inverse_w0 = @interpolator.inverse_clip_w(v0[:position])
          inverse_w1 = @interpolator.inverse_clip_w(v1[:position])
          inverse_w2 = @interpolator.inverse_clip_w(v2[:position])
          interpolation_plan = @interpolator.prepare([v0, v1, v2])
          attributes = ShaderIO.new
          fragment_output = ShaderIO.new

          x = min_x + 0.5
          y = min_y + 0.5
          row_w0 = edge_value(p1, p2, x, y)
          row_w1 = edge_value(p2, p0, x, y)
          row_w2 = edge_value(p0, p1, x, y)
          x_steps = [p2.y - p1.y, p0.y - p2.y, p1.y - p0.y]
          y_steps = [p1.x - p2.x, p2.x - p0.x, p0.x - p1.x]
          positive_area = area.positive?

          (min_y..max_y).each do |pixel_y|
            w0 = row_w0
            w1 = row_w1
            w2 = row_w2
            (min_x..max_x).each do |pixel_x|
              if inside_triangle?(w0, w1, w2, positive_area)
                screen_w0 = w0 * inv_area
                screen_w1 = w1 * inv_area
                screen_w2 = w2 * inv_area
                corrected_w0 = screen_w0 * inverse_w0
                corrected_w1 = screen_w1 * inverse_w1
                corrected_w2 = screen_w2 * inverse_w2
                total = corrected_w0 + corrected_w1 + corrected_w2
                unless total.zero?
                  corrected_w0 /= total
                  corrected_w1 /= total
                  corrected_w2 /= total
                end
                depth = p0.z * corrected_w0 + p1.z * corrected_w1 + p2.z * corrected_w2
                @interpolator.interpolate_triangle(
                  interpolation_plan, corrected_w0, corrected_w1, corrected_w2, result: attributes
                )

                shade_fragment(
                  pixel_x, pixel_y, depth, attributes, fragment_shader, uniforms, state, fragment_output
                )
              end
              w0 += x_steps[0]
              w1 += x_steps[1]
              w2 += x_steps[2]
            end
            row_w0 += y_steps[0]
            row_w1 += y_steps[1]
            row_w2 += y_steps[2]
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

        def edge_value(a, b, x, y)
          (x - a.x) * (b.y - a.y) - (y - a.y) * (b.x - a.x)
        end

        def inside_triangle?(w0, w1, w2, positive_area)
          positive_area ? w0 >= 0 && w1 >= 0 && w2 >= 0 : w0 <= 0 && w1 <= 0 && w2 <= 0
        end

        def culled?(area, cull_mode)
          case cull_mode
          when :back then area < 0
          when :front then area > 0
          else false
          end
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
