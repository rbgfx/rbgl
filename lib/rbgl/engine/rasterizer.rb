# frozen_string_literal: true

module RBGL
  module Engine
    class Rasterizer
      attr_accessor :viewport

      def initialize(framebuffer)
        @framebuffer = framebuffer
        @viewport = { x: 0, y: 0, width: framebuffer.width, height: framebuffer.height }
      end

      def resize(width, height)
        @viewport = @viewport.merge(width: width, height: height)
      end

      def rasterize_triangle(v0, v1, v2, fragment_shader, uniforms, cull_mode: :none,
                             depth_test: true, depth_write: true, blend_mode: :none)
        p0 = viewport_transform(v0[:position])
        p1 = viewport_transform(v1[:position])
        p2 = viewport_transform(v2[:position])

        min_x = [p0.x, p1.x, p2.x].min.floor.clamp(0, @framebuffer.width - 1)
        max_x = [p0.x, p1.x, p2.x].max.ceil.clamp(0, @framebuffer.width - 1)
        min_y = [p0.y, p1.y, p2.y].min.floor.clamp(0, @framebuffer.height - 1)
        max_y = [p0.y, p1.y, p2.y].max.ceil.clamp(0, @framebuffer.height - 1)

        area = edge_function(p0, p1, p2)
        return if area.abs < 1e-10

        case cull_mode
        when :back
          return if area < 0
        when :front
          return if area > 0
        end

        (min_y..max_y).each do |y|
          (min_x..max_x).each do |x|
            px = x + 0.5
            py = y + 0.5
            p = Larb::Vec2.new(px, py)

            w0 = edge_function(p1, p2, p)
            w1 = edge_function(p2, p0, p)
            w2 = edge_function(p0, p1, p)

            if (w0 >= 0 && w1 >= 0 && w2 >= 0) || (w0 <= 0 && w1 <= 0 && w2 <= 0)
              inv_area = 1.0 / area
              w0 *= inv_area
              w1 *= inv_area
              w2 *= inv_area

              depth = w0 * p0.z + w1 * p1.z + w2 * p2.z

              interpolated = interpolate_attributes(v0, v1, v2, w0, w1, w2)

              frag_output = fragment_shader.process(interpolated, uniforms)
              color = frag_output[:color]

              @framebuffer.write_pixel(
                x, y, color, depth,
                depth_test: depth_test,
                depth_write: depth_write,
                blend_mode: blend_mode
              )
            end
          end
        end
      end

      def rasterize_line(v0, v1, fragment_shader, uniforms, cull_mode: :none,
                         depth_test: true, depth_write: true, blend_mode: :none)
        p0 = viewport_transform(v0[:position])
        p1 = viewport_transform(v1[:position])

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
          current_dist = Math.sqrt((x0 - p0.x.round)**2 + (y0 - p0.y.round)**2)
          t = total_dist > 0 ? current_dist / total_dist : 0

          depth = p0.z + (p1.z - p0.z) * t

          interpolated = interpolate_line_attributes(v0, v1, t)

          frag_output = fragment_shader.process(interpolated, uniforms)
          @framebuffer.write_pixel(
            x0, y0, frag_output[:color], depth,
            depth_test: depth_test,
            depth_write: depth_write,
            blend_mode: blend_mode
          )

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

      def rasterize_point(vertex, fragment_shader, uniforms, cull_mode: :none, size: 1,
                          depth_test: true, depth_write: true, blend_mode: :none)
        p = viewport_transform(vertex[:position])
        x = p.x.round
        y = p.y.round
        depth = p.z

        half = size / 2
        (-half..half).each do |dy|
          (-half..half).each do |dx|
            frag_output = fragment_shader.process(vertex, uniforms)
            @framebuffer.write_pixel(
              x + dx, y + dy, frag_output[:color], depth,
              depth_test: depth_test,
              depth_write: depth_write,
              blend_mode: blend_mode
            )
          end
        end
      end

      private

      def viewport_transform(position)
        ndc = if position.is_a?(Larb::Vec4)
                position.perspective_divide
              else
                position
              end

        Larb::Vec3.new(
          (ndc.x + 1) * 0.5 * @viewport[:width] + @viewport[:x],
          (1 - ndc.y) * 0.5 * @viewport[:height] + @viewport[:y],
          (ndc.z + 1) * 0.5
        )
      end

      def edge_function(a, b, c)
        (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x)
      end

      def interpolate_attributes(v0, v1, v2, w0, w1, w2)
        interpolate_attribute_set([v0, v1, v2]) do |a0, a1, a2|
          interpolate_value(a0, a1, a2, w0, w1, w2)
        end
      end

      def interpolate_value(a, b, c, w0, w1, w2)
        case a
        when Larb::Vec2
          Larb::Vec2.new(
            a.x * w0 + b.x * w1 + c.x * w2,
            a.y * w0 + b.y * w1 + c.y * w2
          )
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
        when Numeric
          a * w0 + b * w1 + c * w2
        else
          a
        end
      end

      def interpolate_line_attributes(v0, v1, t)
        interpolate_attribute_set([v0, v1]) do |a0, a1|
          interpolate_value(a0, a1, a1, 1.0 - t, t, 0.0)
        end
      end

      def interpolate_attribute_set(vertices)
        result = ShaderIO.new

        interpolated_keys(vertices).each do |key|
          values = vertices.map { |vertex| vertex[key] }
          next if values.any?(&:nil?)

          result[key] = yield(*values)
        end

        result
      end

      def interpolated_keys(vertices)
        vertices.flat_map { |vertex| vertex.to_h.keys }.uniq - [:position]
      end
    end
  end
end
