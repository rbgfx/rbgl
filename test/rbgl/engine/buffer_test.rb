# frozen_string_literal: true

require_relative "../../test_helper"

class VertexAttributeTest < Test::Unit::TestCase
  test "initializes with name, size, and offset" do
    attr = RBGL::Engine::VertexAttribute.new(:position, 3, 0)
    assert_equal :position, attr.name
    assert_equal 3, attr.size
    assert_equal 0, attr.offset
  end

  test "converts string name to symbol" do
    attr = RBGL::Engine::VertexAttribute.new("color", 4, 3)
    assert_equal :color, attr.name
    assert_equal :color, attr.kind
  end

  test "default offset is 0" do
    attr = RBGL::Engine::VertexAttribute.new(:uv, 2)
    assert_equal 0, attr.offset
  end

  test "supports explicit attribute kind" do
    attr = RBGL::Engine::VertexAttribute.new(:tint, 4, 0, kind: :color)

    assert_equal :color, attr.kind
  end
end

class VertexLayoutTest < Test::Unit::TestCase
  test "creates empty layout" do
    layout = RBGL::Engine::VertexLayout.new
    assert_equal({}, layout.attributes)
    assert_equal 0, layout.stride
  end

  test "creates layout with block" do
    layout = RBGL::Engine::VertexLayout.new do
      attribute :position, 3
      attribute :color, 4, kind: :color
    end
    assert_equal 2, layout.attributes.size
    assert_equal 7, layout.stride
    assert_equal :color, layout.attributes[:color].kind
  end

  test "position_only creates layout with position attribute" do
    layout = RBGL::Engine::VertexLayout.position_only
    assert layout.attributes.key?(:position)
    assert_equal 3, layout.attributes[:position].size
  end

  test "position_color creates layout with position and color" do
    layout = RBGL::Engine::VertexLayout.position_color
    assert layout.attributes.key?(:position)
    assert layout.attributes.key?(:color)
    assert_equal 7, layout.stride
  end

  test "position_normal_uv creates correct layout" do
    layout = RBGL::Engine::VertexLayout.position_normal_uv
    assert_equal 8, layout.stride
    assert layout.attributes.key?(:position)
    assert layout.attributes.key?(:normal)
    assert layout.attributes.key?(:uv)
  end

  test "position_normal_uv_color creates correct layout" do
    layout = RBGL::Engine::VertexLayout.position_normal_uv_color
    assert_equal 12, layout.stride
  end
end

class VertexBufferTest < Test::Unit::TestCase
  setup do
    @layout = RBGL::Engine::VertexLayout.position_color
  end

  test "initializes empty buffer" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    assert_equal 0, buffer.vertex_count
    assert_equal [], buffer.data
  end

  test "adds vertex with array values" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    buffer.add_vertex(position: [1.0, 2.0, 3.0], color: [1.0, 0.0, 0.0, 1.0])
    assert_equal 1, buffer.vertex_count
    assert_equal 7, buffer.data.size
  end

  test "adds vertex with Larb types" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    buffer.add_vertex(
      position: Larb::Vec3.new(1.0, 2.0, 3.0),
      color: Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    )
    assert_equal 1, buffer.vertex_count
  end

  test "truncates extra components to match attribute size" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)

    buffer.add_vertex(
      position: Larb::Vec4.new(1.0, 2.0, 3.0, 1.0),
      color: Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    )

    vertex = buffer.get_vertex(0)
    assert_equal 1.0, vertex[:position].x
    assert_equal 3.0, vertex[:position].z
  end

  test "adds numeric attributes as floats and restores scalar values" do
    layout = RBGL::Engine::VertexLayout.new do
      attribute :weight, 1
    end
    buffer = RBGL::Engine::VertexBuffer.new(layout)

    buffer.add_vertex(weight: 2)

    assert_equal [2.0], buffer.data
    assert_equal 2.0, buffer.get_vertex(0)[:weight]
  end

  test "restores array attributes larger than vec4" do
    layout = RBGL::Engine::VertexLayout.new do
      attribute :weights, 5
    end
    buffer = RBGL::Engine::VertexBuffer.new(layout)

    buffer.add_vertex(weights: [1, 2, 3, 4, 5])

    assert_equal [1.0, 2.0, 3.0, 4.0, 5.0], buffer.get_vertex(0)[:weights]
  end

  test "restores vec2 and vec4 attributes" do
    layout = RBGL::Engine::VertexLayout.new do
      attribute :uv, 2
      attribute :tangent, 4
    end
    buffer = RBGL::Engine::VertexBuffer.new(layout)

    buffer.add_vertex(
      uv: Larb::Vec2.new(0.25, 0.75),
      tangent: Larb::Vec4.new(1.0, 0.0, 0.0, 1.0)
    )
    vertex = buffer.get_vertex(0)

    assert_kind_of Larb::Vec2, vertex[:uv]
    assert_equal 0.25, vertex[:uv].x
    assert_equal 0.75, vertex[:uv].y
    assert_kind_of Larb::Vec4, vertex[:tangent]
    assert_equal 1.0, vertex[:tangent].x
    assert_equal 1.0, vertex[:tangent].w
  end

  test "add_vertex returns self for chaining" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    result = buffer.add_vertex(position: [0, 0, 0], color: [1, 1, 1, 1])
    assert_same buffer, result
  end

  test "add_vertices adds multiple vertices" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    buffer.add_vertices(
      { position: [0, 0, 0], color: [1, 1, 1, 1] },
      { position: [1, 0, 0], color: [1, 0, 0, 1] }
    )
    assert_equal 2, buffer.vertex_count
  end

  test "get_vertex returns vertex data" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    buffer.add_vertex(position: [1.0, 2.0, 3.0], color: [0.5, 0.5, 0.5, 1.0])
    vertex = buffer.get_vertex(0)
    assert_kind_of Larb::Vec3, vertex[:position]
    assert_kind_of Larb::Color, vertex[:color]
  end

  test "get_vertex returns nil for invalid index" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    assert_nil buffer.get_vertex(0)
    assert_nil buffer.get_vertex(-1)
  end

  test "raises error for missing attribute" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)
    assert_raise(ArgumentError) do
      buffer.add_vertex(position: [0, 0, 0])
    end
  end

  test "raises error for unknown attributes" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)

    assert_raise(ArgumentError) do
      buffer.add_vertex(position: [0, 0, 0], color: [1, 1, 1, 1], postion: [0, 0, 0])
    end
  end

  test "raises error for attribute values with the wrong arity" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)

    assert_raise(ArgumentError) do
      buffer.add_vertex(position: [0, 0], color: [1, 1, 1, 1])
    end
  end

  test "raises error for unsupported attribute value types" do
    buffer = RBGL::Engine::VertexBuffer.new(@layout)

    assert_raise(ArgumentError) do
      buffer.add_vertex(position: Object.new, color: [1, 1, 1, 1])
    end
  end

  test "explicit color kind restores custom color attributes" do
    layout = RBGL::Engine::VertexLayout.new do
      attribute :tint, 4, kind: :color
    end
    buffer = RBGL::Engine::VertexBuffer.new(layout)

    buffer.add_vertex(tint: [0.1, 0.2, 0.3, 1.0])

    assert_kind_of Larb::Color, buffer.get_vertex(0)[:tint]
  end

  test "from_array creates buffer from data" do
    data = [
      { position: [0, 0, 0], color: [1, 1, 1, 1] },
      { position: [1, 0, 0], color: [1, 0, 0, 1] }
    ]
    buffer = RBGL::Engine::VertexBuffer.from_array(@layout, data)
    assert_equal 2, buffer.vertex_count
  end
end

class IndexBufferTest < Test::Unit::TestCase
  test "initializes empty buffer" do
    buffer = RBGL::Engine::IndexBuffer.new
    assert_equal [], buffer.indices
  end

  test "initializes with indices" do
    buffer = RBGL::Engine::IndexBuffer.new([0, 1, 2])
    assert_equal [0, 1, 2], buffer.indices
  end

  test "converts indices to integers" do
    buffer = RBGL::Engine::IndexBuffer.new([0.5, 1.7, 2.9])
    assert_equal [0, 1, 2], buffer.indices
  end

  test "add appends indices" do
    buffer = RBGL::Engine::IndexBuffer.new([0, 1, 2])
    buffer.add(3, 4, 5)
    assert_equal [0, 1, 2, 3, 4, 5], buffer.indices
  end

  test "add returns self for chaining" do
    buffer = RBGL::Engine::IndexBuffer.new
    result = buffer.add(0, 1, 2)
    assert_same buffer, result
  end

  test "triangle_count returns correct count" do
    buffer = RBGL::Engine::IndexBuffer.new([0, 1, 2, 3, 4, 5])
    assert_equal 2, buffer.triangle_count
  end

  test "get_triangle returns triangle indices" do
    buffer = RBGL::Engine::IndexBuffer.new([0, 1, 2, 3, 4, 5])
    assert_equal [0, 1, 2], buffer.get_triangle(0)
    assert_equal [3, 4, 5], buffer.get_triangle(1)
  end

  test "each_triangle yields triangles" do
    buffer = RBGL::Engine::IndexBuffer.new([0, 1, 2, 3, 4, 5])
    triangles = buffer.each_triangle.to_a
    assert_equal 2, triangles.size
    assert_equal [0, 1, 2], triangles[0]
  end

  test "each_triangle returns enumerator without block" do
    buffer = RBGL::Engine::IndexBuffer.new([0, 1, 2])
    assert_kind_of Enumerator, buffer.each_triangle
  end
end
