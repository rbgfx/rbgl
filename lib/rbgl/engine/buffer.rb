# frozen_string_literal: true

module RBGL
  module Engine
    class VertexAttribute
      attr_reader :name, :size, :offset, :kind

      def initialize(name, size, offset = 0, kind: nil)
        unless size.is_a?(Integer) && size.positive?
          raise ArgumentError, "Vertex attribute size must be a positive Integer"
        end

        @name = name.to_sym
        @size = size
        @offset = offset
        @kind = (kind || infer_kind).to_sym
        validate_kind!
      end

      def serialize(value)
        values = extract_values(value)
        validate_value_size!(values)
        values.first(@size).map { |component| Float(component) }
      rescue ArgumentError, TypeError => e
        raise ArgumentError, "Invalid value for attribute #{name}: #{e.message}"
      end

      def deserialize(values)
        case @kind
        when :scalar
          values[0]
        when :vec2
          Larb::Vec2.new(*values)
        when :vec3
          Larb::Vec3.new(*values)
        when :vec4
          Larb::Vec4.new(*values)
        when :color
          Larb::Color.new(*values)
        when :array
          values.dup
        end
      end

      private

      def infer_kind
        return :color if @name == :color && @size == 4

        case @size
        when 1 then :scalar
        when 2 then :vec2
        when 3 then :vec3
        when 4 then :vec4
        else :array
        end
      end

      def validate_kind!
        expected_sizes = {
          scalar: [1],
          vec2: [2],
          vec3: [3],
          vec4: [4],
          color: [4],
          array: nil
        }.fetch(@kind) do
          raise ArgumentError, "Unsupported attribute kind: #{@kind}"
        end

        return if expected_sizes.nil? || expected_sizes.include?(@size)

        raise ArgumentError, "Attribute #{name} kind #{@kind} requires size #{expected_sizes.join(' or ')}"
      end

      def extract_values(value)
        case value
        when Larb::Vec2
          [value.x, value.y]
        when Larb::Vec3
          [value.x, value.y, value.z]
        when Larb::Vec4
          [value.x, value.y, value.z, value.w]
        when Larb::Color
          value.to_a
        when Array
          value
        when Numeric
          [value]
        else
          raise ArgumentError, "Unsupported attribute type #{value.class}"
        end
      end

      def validate_value_size!(values)
        return if values.size >= @size

        raise ArgumentError, "Expected at least #{@size} components, got #{values.size}"
      end
    end

    class VertexLayout
      attr_reader :stride

      def initialize(&block)
        @attributes = {}
        @offset = 0
        @stride = 0
        @finalized = false
        instance_eval(&block) if block_given?
      end

      def attribute(name, size, kind: nil)
        raise ArgumentError, "Vertex layout is finalized" if @finalized

        key = name.to_sym
        raise ArgumentError, "Duplicate vertex attribute: #{key}" if @attributes.key?(key)

        @attributes[key] = VertexAttribute.new(key, size, @offset, kind: kind)
        @offset += size
        @stride = @offset
      end

      def attributes
        @finalized ? @attributes : @attributes.dup.freeze
      end

      def finalize!
        @finalized = true
        @attributes.freeze
        self
      end

      def self.position_only
        new { attribute :position, 3 }
      end

      def self.position_color
        new do
          attribute :position, 3
          attribute :color, 4
        end
      end

      def self.position_normal_uv
        new do
          attribute :position, 3
          attribute :normal, 3
          attribute :uv, 2
        end
      end

      def self.position_normal_uv_color
        new do
          attribute :position, 3
          attribute :normal, 3
          attribute :uv, 2
          attribute :color, 4
        end
      end
    end

    class VertexBuffer
      attr_reader :data, :layout, :vertex_count

      def initialize(layout)
        unless layout.is_a?(VertexLayout)
          raise ArgumentError, "VertexBuffer layout must be an RBGL::Engine::VertexLayout"
        end

        @layout = layout.finalize!
        @data = []
        @vertex_count = 0
      end

      def add_vertex(**attributes)
        validate_attribute_keys!(attributes)

        vertex_data = []
        @layout.attributes.each do |name, attr|
          raise ArgumentError, "Missing attribute: #{name}" unless attributes.key?(name)

          vertex_data.concat(attr.serialize(attributes[name]))
        end
        @data.concat(vertex_data)
        @vertex_count += 1
        self
      end

      def add_vertices(*vertices)
        vertices.each { |v| add_vertex(**v) }
        self
      end

      def get_vertex(index)
        return nil if index < 0 || index >= @vertex_count

        start = index * @layout.stride
        vertex = {}

        @layout.attributes.each do |name, attr|
          offset = start + attr.offset
          values = @data[offset, attr.size]
          vertex[name] = attr.deserialize(values)
        end

        vertex
      end

      def self.from_array(layout, data)
        buffer = new(layout)
        data.each { |vertex| buffer.add_vertex(**vertex) }
        buffer
      end

      private

      def validate_attribute_keys!(attributes)
        unknown_attributes = attributes.keys.map(&:to_sym) - @layout.attributes.keys
        return if unknown_attributes.empty?

        raise ArgumentError, "Unknown attributes: #{unknown_attributes.join(', ')}"
      end
    end

    class IndexBuffer
      def initialize(indices = [])
        @indices = validate_indices!(indices)
      end

      def indices
        @indices.dup.freeze
      end

      def add(*idx)
        @indices.concat(validate_indices!(idx.flatten))
        self
      end

      def triangle_count
        @indices.size / 3
      end

      def get_triangle(index)
        return nil unless index.is_a?(Integer) && index >= 0

        start = index * 3
        @indices[start, 3]
      end

      def each_triangle
        return enum_for(:each_triangle) unless block_given?

        (0...triangle_count).each { |i| yield get_triangle(i) }
      end

      private

      def validate_indices!(indices)
        indices.map do |index|
          unless index.is_a?(Integer) && index >= 0
            raise ArgumentError, "Index must be a non-negative Integer: #{index.inspect}"
          end

          index
        end
      end
    end
  end
end
