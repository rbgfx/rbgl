# frozen_string_literal: true

module RBGL
  module Engine
    class Context
      attr_reader :framebuffer, :rasterizer

      def initialize(width:, height:)
        @framebuffer = Framebuffer.new(width, height)
        @rasterizer = Rasterizer.new(@framebuffer)
        @pipeline = nil
        @uniforms = Uniforms.new
        @vertex_buffer = nil
        @index_buffer = nil
      end

      def bind_pipeline(pipeline)
        @pipeline = pipeline
      end

      def bind_vertex_buffer(buffer)
        @vertex_buffer = buffer
      end

      def bind_index_buffer(buffer)
        @index_buffer = buffer
      end

      def set_uniform(name, value)
        @uniforms[name] = value
      end

      def set_uniforms(hash)
        hash.each { |k, v| @uniforms[k] = v }
      end

      def clear(color: Larb::Color.black, depth: Float::INFINITY)
        @framebuffer.clear(color: color, depth: depth)
      end

      def resize(width:, height:)
        @framebuffer.resize(width, height)
        @rasterizer.resize(width, height)
      end

      def draw_arrays(mode, first, count)
        validate_draw_state!
        draw_vertices(mode, first...first + count)
      end

      def draw_elements(mode, count, offset = 0)
        validate_draw_state!(indexed: true)
        indices = @index_buffer.indices[offset, count] || []
        draw_vertices(mode, indices, vertex_cache: {})
      end

      def width
        @framebuffer.width
      end

      def height
        @framebuffer.height
      end

      def aspect_ratio
        width.to_f / height
      end

      private

      def validate_draw_state!(indexed: false)
        raise "No pipeline bound" unless @pipeline
        raise "No vertex buffer bound" unless @vertex_buffer
        raise "No index buffer bound" if indexed && !@index_buffer
      end

      def draw_vertices(mode, indices, vertex_cache: nil)
        each_primitive(mode, indices) do |primitive_indices|
          primitive = primitive_indices.map { |index| fetch_vertex(index, vertex_cache) }
          draw_primitive(mode, primitive)
        end
      end

      def each_primitive(mode, vertices)
        return enum_for(:each_primitive, mode, vertices) unless block_given?

        vertices = vertices.to_a unless vertices.respond_to?(:[])

        case mode
        when :triangles
          each_slice(vertices, 3) { |triangle| yield triangle }
        when :lines
          each_slice(vertices, 2) { |line| yield line }
        when :points
          vertices.each { |vertex| yield [vertex] }
        when :triangle_strip
          (0...vertices.size - 2).each do |index|
            if index.even?
              yield [vertices[index], vertices[index + 1], vertices[index + 2]]
            else
              yield [vertices[index], vertices[index + 2], vertices[index + 1]]
            end
          end
        when :triangle_fan
          (1...vertices.size - 1).each do |index|
            yield [vertices[0], vertices[index], vertices[index + 1]]
          end
        end
      end

      def each_slice(vertices, size)
        vertices.each_slice(size) do |primitive|
          next unless primitive.size == size

          yield primitive
        end
      end

      def draw_primitive(mode, primitive)
        case mode
        when :lines
          draw_line(*primitive)
        when :points
          draw_point(primitive.first)
        else
          draw_triangle(*primitive)
        end
      end

      def process_vertex(index)
        input = @vertex_buffer.get_vertex(index)
        return nil unless input

        input_io = ShaderIO.new
        input.each { |k, v| input_io[k] = v }

        @pipeline.vertex_shader.process(input_io, @uniforms)
      end

      def fetch_vertex(index, vertex_cache)
        return process_vertex(index) unless vertex_cache
        return vertex_cache[index] if vertex_cache.key?(index)

        vertex_cache[index] = process_vertex(index)
      end

      def draw_triangle(v0, v1, v2)
        return unless v0 && v1 && v2
        return if clip_triangle?(v0, v1, v2)

        @rasterizer.rasterize_triangle(
          v0, v1, v2,
          @pipeline.fragment_shader,
          @uniforms,
          **rasterizer_state
        )
      end

      def draw_line(v0, v1)
        return unless v0 && v1

        @rasterizer.rasterize_line(v0, v1, @pipeline.fragment_shader, @uniforms, **rasterizer_state)
      end

      def draw_point(v)
        return unless v

        @rasterizer.rasterize_point(v, @pipeline.fragment_shader, @uniforms, **rasterizer_state)
      end

      def clip_triangle?(v0, v1, v2)
        positions = [v0[:position], v1[:position], v2[:position]].map do |p|
          if p.is_a?(Larb::Vec4)
            p.perspective_divide
          else
            p
          end
        end

        positions.all? { |p| p.x < -1 } ||
          positions.all? { |p| p.x > 1 } ||
          positions.all? { |p| p.y < -1 } ||
          positions.all? { |p| p.y > 1 } ||
          positions.all? { |p| p.z < -1 } ||
          positions.all? { |p| p.z > 1 }
      end

      def rasterizer_state
        {
          cull_mode: @pipeline.cull_mode,
          depth_test: @pipeline.depth_test,
          depth_write: @pipeline.depth_write,
          blend_mode: @pipeline.blend_mode
        }
      end
    end
  end
end
