# frozen_string_literal: true

require_relative "../../test_helper"

class ContextTest < Test::Unit::TestCase
  setup do
    @ctx = RBGL::Engine::Context.new(width: 100, height: 100)
    @pipeline = RBGL::Engine::Pipeline.create do
      vertex do |input, _uniforms, output|
        output.position = input[:position]
        output.color = input[:color]
      end
      fragment do |input, _uniforms, output|
        output.color = input[:color] || Larb::Color.new(1, 1, 1, 1)
      end
    end
    @layout = RBGL::Engine::VertexLayout.position_color
    @vb = RBGL::Engine::VertexBuffer.new(@layout)
    @ib = RBGL::Engine::IndexBuffer.new
  end

  test "initializes with framebuffer and rasterizer" do
    assert_kind_of RBGL::Engine::Framebuffer, @ctx.framebuffer
    assert_kind_of RBGL::Engine::Rasterizer, @ctx.rasterizer
  end

  test "width returns framebuffer width" do
    assert_equal 100, @ctx.width
  end

  test "height returns framebuffer height" do
    assert_equal 100, @ctx.height
  end

  test "aspect_ratio returns correct ratio" do
    assert_equal 1.0, @ctx.aspect_ratio
  end

  test "bind_pipeline stores pipeline" do
    @ctx.bind_pipeline(@pipeline)
  end

  test "bind_vertex_buffer stores buffer" do
    @ctx.bind_vertex_buffer(@vb)
  end

  test "bind_index_buffer stores buffer" do
    @ctx.bind_index_buffer(@ib)
  end

  test "set_uniform sets single uniform" do
    @ctx.set_uniform(:time, 1.0)
  end

  test "set_uniforms sets multiple uniforms" do
    @ctx.set_uniforms(time: 1.0, mouse: [0, 0])
  end

  test "clear resets framebuffer" do
    red = Larb::Color.new(1.0, 0.0, 0.0, 1.0)
    @ctx.framebuffer.set_pixel(50, 50, red)
    @ctx.clear
    assert_equal 0.0, @ctx.framebuffer.get_pixel(50, 50).r
  end

  test "resize updates framebuffer dimensions" do
    @ctx.resize(width: 64, height: 48)

    assert_equal 64, @ctx.width
    assert_equal 48, @ctx.height
  end

  test "draw_arrays raises without pipeline" do
    @ctx.bind_vertex_buffer(@vb)
    assert_raise(RuntimeError) do
      @ctx.draw_arrays(:triangles, 0, 3)
    end
  end

  test "draw_arrays raises without vertex buffer" do
    @ctx.bind_pipeline(@pipeline)
    assert_raise(RuntimeError) do
      @ctx.draw_arrays(:triangles, 0, 3)
    end
  end

  test "draw_arrays with triangles mode" do
    setup_triangle
    @ctx.draw_arrays(:triangles, 0, 3)
  end

  test "draw_arrays with lines mode" do
    @ctx.bind_pipeline(@pipeline)
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, 0, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, 0, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @ctx.bind_vertex_buffer(@vb)
    @ctx.draw_arrays(:lines, 0, 2)
  end

  test "draw_arrays with points mode" do
    @ctx.bind_pipeline(@pipeline)
    @vb.add_vertex(position: Larb::Vec4.new(0, 0, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @ctx.bind_vertex_buffer(@vb)
    @ctx.draw_arrays(:points, 0, 1)
  end

  test "draw_arrays with triangle_strip mode" do
    setup_quad_strip
    @ctx.draw_arrays(:triangle_strip, 0, 4)
  end

  test "draw_arrays with triangle_fan mode" do
    setup_quad_strip
    @ctx.draw_arrays(:triangle_fan, 0, 4)
  end

  test "draw_elements raises without index buffer" do
    @ctx.bind_pipeline(@pipeline)
    @ctx.bind_vertex_buffer(@vb)
    assert_raise(RuntimeError) do
      @ctx.draw_elements(:triangles, 3)
    end
  end

  test "draw_elements with triangles mode" do
    setup_indexed_triangle
    @ctx.draw_elements(:triangles, 3)
  end

  test "draw_elements with lines mode" do
    @ctx.bind_pipeline(@pipeline)
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, 0, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, 0, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @ib.add(0, 1)
    @ctx.bind_vertex_buffer(@vb)
    @ctx.bind_index_buffer(@ib)
    @ctx.draw_elements(:lines, 2)
  end

  test "draw_elements with triangle_strip mode" do
    setup_indexed_quad_strip
    @ctx.draw_elements(:triangle_strip, 4)
  end

  test "draw_elements with triangle_fan mode" do
    setup_indexed_quad_strip
    @ctx.draw_elements(:triangle_fan, 4)
  end

  test "draw_arrays raises for unsupported primitive mode" do
    setup_triangle

    assert_raise(ArgumentError) do
      @ctx.draw_arrays(:quads, 0, 4)
    end
  end

  test "draw_elements raises for unsupported primitive mode" do
    setup_indexed_triangle

    assert_raise(ArgumentError) do
      @ctx.draw_elements(:quads, 3)
    end
  end

  test "draw_elements caches processed vertices for repeated indices" do
    vertex_calls = 0
    pipeline = RBGL::Engine::Pipeline.create do
      self.cull_mode = :none

      vertex do |input, _uniforms, output|
        vertex_calls += 1
        output.position = input[:position]
        output.color = input[:color]
      end

      fragment do |input, _uniforms, output|
        output.color = input[:color]
      end
    end

    @vb.add_vertex(position: Larb::Vec4.new(0, 0.5, 0, 1), color: Larb::Color.new(1, 0, 0, 1))
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, -0.5, 0, 1), color: Larb::Color.new(0, 1, 0, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, -0.5, 0, 1), color: Larb::Color.new(0, 0, 1, 1))
    @ib.add(0, 1, 2, 0, 2, 1)
    @ctx.bind_pipeline(pipeline)
    @ctx.bind_vertex_buffer(@vb)
    @ctx.bind_index_buffer(@ib)

    @ctx.draw_elements(:triangles, 6)

    assert_equal 3, vertex_calls
  end

  test "clip_triangle? perspective divides Vec4 positions" do
    v0 = RBGL::Engine::ShaderIO.new
    v1 = RBGL::Engine::ShaderIO.new
    v2 = RBGL::Engine::ShaderIO.new

    v0[:position] = Larb::Vec4.new(4.0, 0.0, 0.0, 2.0)
    v1[:position] = Larb::Vec4.new(6.0, 0.0, 0.0, 2.0)
    v2[:position] = Larb::Vec4.new(8.0, 0.0, 0.0, 2.0)

    assert_true @ctx.send(:clip_triangle?, v0, v1, v2)
  end

  test "draw_arrays respects pipeline depth_test setting" do
    render_triangle(color: Larb::Color.new(1, 0, 0, 1), z: 0.0)
    render_triangle(color: Larb::Color.new(0, 0, 1, 1), z: 0.5, depth_test: false)

    color = @ctx.framebuffer.get_pixel(50, 50)
    assert_in_delta 0.0, color.r, 0.001
    assert_in_delta 1.0, color.b, 0.001
  end

  test "draw_arrays respects pipeline depth_write setting" do
    render_triangle(color: Larb::Color.new(1, 0, 0, 1), z: 0.0, depth_write: false)
    render_triangle(color: Larb::Color.new(0, 0, 1, 1), z: 0.5)

    color = @ctx.framebuffer.get_pixel(50, 50)
    assert_in_delta 0.0, color.r, 0.001
    assert_in_delta 1.0, color.b, 0.001
    assert_in_delta 0.75, @ctx.framebuffer.get_depth(50, 50), 0.001
  end

  test "draw_arrays respects pipeline blend mode" do
    render_triangle(color: Larb::Color.new(1, 0, 0, 1), z: 0.0)
    render_triangle(color: Larb::Color.new(0, 0, 1, 0.5), z: -0.1, blend_mode: :alpha)

    color = @ctx.framebuffer.get_pixel(50, 50)
    assert_in_delta 0.5, color.r, 0.001
    assert_in_delta 0.0, color.g, 0.001
    assert_in_delta 0.5, color.b, 0.001
  end

  private

  def setup_triangle
    @ctx.bind_pipeline(@pipeline)
    @vb.add_vertex(position: Larb::Vec4.new(0, 0.5, 0, 1), color: Larb::Color.new(1, 0, 0, 1))
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, -0.5, 0, 1), color: Larb::Color.new(0, 1, 0, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, -0.5, 0, 1), color: Larb::Color.new(0, 0, 1, 1))
    @ctx.bind_vertex_buffer(@vb)
  end

  def setup_quad_strip
    @ctx.bind_pipeline(@pipeline)
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, 0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, -0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, 0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, -0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @ctx.bind_vertex_buffer(@vb)
  end

  def setup_indexed_triangle
    @ctx.bind_pipeline(@pipeline)
    @vb.add_vertex(position: Larb::Vec4.new(0, 0.5, 0, 1), color: Larb::Color.new(1, 0, 0, 1))
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, -0.5, 0, 1), color: Larb::Color.new(0, 1, 0, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, -0.5, 0, 1), color: Larb::Color.new(0, 0, 1, 1))
    @ib.add(0, 1, 2)
    @ctx.bind_vertex_buffer(@vb)
    @ctx.bind_index_buffer(@ib)
  end

  def setup_indexed_quad_strip
    @ctx.bind_pipeline(@pipeline)
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, 0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(-0.5, -0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, 0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @vb.add_vertex(position: Larb::Vec4.new(0.5, -0.5, 0, 1), color: Larb::Color.new(1, 1, 1, 1))
    @ib.add(0, 1, 2, 3)
    @ctx.bind_vertex_buffer(@vb)
    @ctx.bind_index_buffer(@ib)
  end

  def render_triangle(color:, z:, depth_test: true, depth_write: true, blend_mode: :none)
    pipeline = RBGL::Engine::Pipeline.create do
      self.cull_mode = :none
      self.depth_test = depth_test
      self.depth_write = depth_write
      self.blend_mode = blend_mode

      vertex do |input, _uniforms, output|
        output.position = input[:position]
        output.color = input[:color]
      end

      fragment do |input, _uniforms, output|
        output.color = input[:color]
      end
    end

    vb = RBGL::Engine::VertexBuffer.new(@layout)
    vb.add_vertex(position: Larb::Vec3.new(0, 0.5, z), color: color)
    vb.add_vertex(position: Larb::Vec3.new(-0.5, -0.5, z), color: color)
    vb.add_vertex(position: Larb::Vec3.new(0.5, -0.5, z), color: color)

    @ctx.bind_pipeline(pipeline)
    @ctx.bind_vertex_buffer(vb)
    @ctx.draw_arrays(:triangles, 0, 3)
  end
end
