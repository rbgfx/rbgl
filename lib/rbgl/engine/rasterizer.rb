# frozen_string_literal: true

require_relative "rasterizer/attribute_interpolator"
require_relative "rasterizer/triangle_renderer"
require_relative "rasterizer/line_renderer"
require_relative "rasterizer/point_renderer"

module RBGL
  module Engine
    class Rasterizer
      attr_accessor :viewport

      def initialize(framebuffer)
        @framebuffer = framebuffer
        @viewport = { x: 0, y: 0, width: framebuffer.width, height: framebuffer.height }
        @attribute_interpolator = AttributeInterpolator.new
        @triangle_renderer = TriangleRenderer.new(
          framebuffer,
          interpolator: @attribute_interpolator,
          viewport_transform: method(:viewport_transform),
          edge_function: method(:edge_function)
        )
        @line_renderer = LineRenderer.new(
          framebuffer,
          interpolator: @attribute_interpolator,
          viewport_transform: method(:viewport_transform)
        )
        @point_renderer = PointRenderer.new(
          framebuffer,
          viewport_transform: method(:viewport_transform),
          point_pixel_offsets: method(:point_pixel_offsets)
        )
      end

      def resize(width, height)
        @viewport = @viewport.merge(width: width, height: height)
      end

      def rasterize_triangle(v0, v1, v2, fragment_shader, uniforms, cull_mode: :none,
                             depth_test: true, depth_write: true, blend_mode: :none)
        @triangle_renderer.rasterize(v0, v1, v2, fragment_shader, uniforms, state(
          cull_mode: cull_mode,
          depth_test: depth_test,
          depth_write: depth_write,
          blend_mode: blend_mode
        ))
      end

      def rasterize_line(v0, v1, fragment_shader, uniforms, cull_mode: :none,
                         depth_test: true, depth_write: true, blend_mode: :none)
        @line_renderer.rasterize(v0, v1, fragment_shader, uniforms, state(
          cull_mode: cull_mode,
          depth_test: depth_test,
          depth_write: depth_write,
          blend_mode: blend_mode
        ))
      end

      def rasterize_point(vertex, fragment_shader, uniforms, size: 1,
                          depth_test: true, depth_write: true, blend_mode: :none)
        @point_renderer.rasterize(vertex, fragment_shader, uniforms, {
          size: size,
          depth_test: depth_test,
          depth_write: depth_write,
          blend_mode: blend_mode
        })
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

      def state(cull_mode:, depth_test:, depth_write:, blend_mode:)
        {
          cull_mode: cull_mode,
          depth_test: depth_test,
          depth_write: depth_write,
          blend_mode: blend_mode
        }
      end

      def point_pixel_offsets(size)
        pixel_size = [size.to_i, 1].max
        min_offset = -(pixel_size / 2.0).floor
        max_offset = ((pixel_size - 1) / 2.0).floor
        offsets = (min_offset..max_offset).to_a
        [offsets, offsets]
      end
    end
  end
end
