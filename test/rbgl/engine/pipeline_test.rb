# frozen_string_literal: true

require_relative "../../test_helper"

class PipelineTest < Test::Unit::TestCase
  test "initializes with default values" do
    pipeline = RBGL::Engine::Pipeline.new
    assert_nil pipeline.vertex_shader
    assert_nil pipeline.fragment_shader
    assert_true pipeline.depth_test
    assert_true pipeline.depth_write
    assert_equal :back, pipeline.cull_mode
    assert_equal :none, pipeline.blend_mode
  end

  test "create with block configures pipeline" do
    pipeline = RBGL::Engine::Pipeline.create do
      self.depth_test = false
      self.cull_mode = :none
    end
    assert_false pipeline.depth_test
    assert_equal :none, pipeline.cull_mode
  end

  test "vertex method creates vertex shader" do
    pipeline = RBGL::Engine::Pipeline.create do
      vertex do |_input, _uniforms, output|
        output.position = Larb::Vec4.new(0, 0, 0, 1)
      end
    end
    assert_kind_of RBGL::Engine::VertexShader, pipeline.vertex_shader
  end

  test "fragment method creates fragment shader" do
    pipeline = RBGL::Engine::Pipeline.create do
      fragment do |_input, _uniforms, output|
        output.color = Larb::Color.new(1, 0, 0, 1)
      end
    end
    assert_kind_of RBGL::Engine::FragmentShader, pipeline.fragment_shader
  end

  test "can set shaders directly" do
    pipeline = RBGL::Engine::Pipeline.new
    vs = RBGL::Engine::VertexShader.new { |_, _, o| o.position = Larb::Vec4.new(0, 0, 0, 1) }
    fs = RBGL::Engine::FragmentShader.new { |_, _, o| o.color = Larb::Color.new(1, 1, 1, 1) }

    pipeline.vertex_shader = vs
    pipeline.fragment_shader = fs

    assert_same vs, pipeline.vertex_shader
    assert_same fs, pipeline.fragment_shader
  end

  test "rejects invalid pipeline state values" do
    pipeline = RBGL::Engine::Pipeline.new

    assert_raise(ArgumentError) { pipeline.cull_mode = :bakc }
    assert_raise(ArgumentError) { pipeline.blend_mode = :alph }
    assert_raise(ArgumentError) { pipeline.depth_test = :yes }
    assert_raise(ArgumentError) { pipeline.depth_write = nil }
  end
end
