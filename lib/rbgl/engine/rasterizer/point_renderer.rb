# frozen_string_literal: true

module RBGL
  module Engine
    class Rasterizer
      class PointRenderer
        def initialize(framebuffer, viewport_transform:, point_pixel_offsets:)
          @framebuffer = framebuffer
          @viewport_transform = viewport_transform
          @point_pixel_offsets = point_pixel_offsets
        end

        def rasterize(vertex, fragment_shader, uniforms, state)
          point = @viewport_transform.call(vertex[:position])
          x = point.x.floor
          y = point.y.floor
          depth = point.z
          x_offsets, y_offsets = @point_pixel_offsets.call(state[:size])
          frag_output = fragment_shader.process(vertex, uniforms)

          y_offsets.each do |dy|
            x_offsets.each do |dx|
              @framebuffer.write_pixel(
                x + dx, y + dy, frag_output[:color], depth,
                depth_test: state[:depth_test],
                depth_write: state[:depth_write],
                blend_mode: state[:blend_mode]
              )
            end
          end
        end
      end
    end
  end
end
