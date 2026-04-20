# frozen_string_literal: true

# Minimal renderer benchmarks for RBGL core paths.
# Usage: ruby bench/renderer_bench.rb

require "benchmark"
require "rbgl"

include Larb
include RBGL::Engine

WIDTH = 320
HEIGHT = 240
ITERATIONS = 1_000

def build_context
  Context.new(width: WIDTH, height: HEIGHT)
end

def triangle_pipeline
  Pipeline.create do
    vertex do |input, _uniforms, output|
      output.position = input.position.to_vec4
      output.color = input.color
    end

    fragment do |input, _uniforms, output|
      output.color = input.color
    end
  end.tap { |pipeline| pipeline.cull_mode = :none }
end

def depth_pipeline
  Pipeline.create do
    vertex do |input, _uniforms, output|
      output.position = input.position.to_vec4
      output.color = input.color
    end

    fragment do |input, _uniforms, output|
      output.color = input.color
    end
  end.tap do |pipeline|
    pipeline.cull_mode = :none
    pipeline.depth_test = true
    pipeline.depth_write = true
  end
end

def line_pipeline
  Pipeline.create do
    vertex do |input, _uniforms, output|
      output.position = input.position.to_vec4
      output.color = input.color
    end

    fragment do |input, _uniforms, output|
      output.color = input.color
    end
  end.tap { |pipeline| pipeline.cull_mode = :none }
end

def vertex_layout
  VertexLayout.position_color
end

def clear_case
  context = build_context
  color = Color.from_hex("#123456")

  Benchmark.measure do
    ITERATIONS.times { context.clear(color: color) }
  end
end

def triangle_case
  context = build_context
  context.clear(color: Color.black)

  pipeline = triangle_pipeline
  context.bind_pipeline(pipeline)
  context.bind_vertex_buffer(triangle_vertices)

  Benchmark.measure do
    ITERATIONS.times { context.draw_arrays(:triangles, 0, 3) }
  end
end

def line_case
  context = build_context
  context.clear(color: Color.black)
  context.bind_pipeline(line_pipeline)
  context.bind_vertex_buffer(line_vertices)

  Benchmark.measure do
    ITERATIONS.times { context.draw_arrays(:lines, 0, 2) }
  end
end

def depth_case
  context = build_context
  context.clear(color: Color.black)
  context.bind_pipeline(depth_pipeline)
  context.bind_vertex_buffer(depth_vertices_far)
  context.draw_arrays(:triangles, 0, 3)
  context.bind_vertex_buffer(depth_vertices_near)

  Benchmark.measure do
    ITERATIONS.times do
      context.draw_arrays(:triangles, 0, 3)
      context.draw_arrays(:triangles, 0, 3)
    end
  end
end

def texture_case
  context = build_context
  context.clear(color: Color.black)

  texture = Texture.solid(8, 8, Color.red)
  pipeline = Pipeline.create do
    vertex do |input, _uniforms, output|
      output.position = input.position.to_vec4
      output.uv = Larb::Vec2.new((input.position.x + 1.0) * 0.5, (input.position.y + 1.0) * 0.5)
    end

    fragment do |input, uniforms, output|
      output.color = texture(uniforms.texture, input.uv)
    end
  end

  pipeline.cull_mode = :none
  context.bind_pipeline(pipeline)
  context.bind_vertex_buffer(uv_vertices)
  context.set_uniform(:texture, texture)

  Benchmark.measure do
    ITERATIONS.times { context.draw_arrays(:triangle_strip, 0, 4) }
  end
end

def shader_call_overhead_case
  context = build_context
  pipeline = Pipeline.create do
    vertex do |input, uniforms, output|
      output.position = input.position.to_vec4
      output.color = Color.new(
        uniforms.ramp % 1.0,
        (uniforms.ramp + 0.25) % 1.0,
        (uniforms.ramp + 0.5) % 1.0,
        1.0
      )
    end

    fragment do |input, _uniforms, output|
      output.color = input.color
    end
  end

  context.bind_pipeline(pipeline)
  context.bind_vertex_buffer(shaded_vertices)

  t = 0.0
  Benchmark.measure do
    ITERATIONS.times do
      context.set_uniform(:ramp, Math.sin(t))
      context.draw_arrays(:triangles, 0, 3)
      t += 0.01
    end
  end
end

def gc_alloc_case
  context = build_context
  context.bind_pipeline(triangle_pipeline)
  context.bind_vertex_buffer(triangle_vertices)

  iterations = ITERATIONS
  GC.start
  before = GC.stat(:total_allocated_objects)

  iterations.times do
    context.draw_arrays(:triangles, 0, 3)
  end

  after = GC.stat(:total_allocated_objects)
  allocations_per_op = (after - before).fdiv(iterations)
  puts "GC allocation (objects/op): #{allocations_per_op.round(2)}"
end

def triangle_vertices
  VertexBuffer.from_array(
    vertex_layout,
    [
      { position: Vec3[-0.5, 0.6, 0.0], color: Color.red },
      { position: Vec3[-0.7, -0.4, 0.0], color: Color.green },
      { position: Vec3[0.6, -0.4, 0.0], color: Color.blue }
    ]
  )
end

def line_vertices
  VertexBuffer.from_array(
    vertex_layout,
    [
      { position: Vec3[-0.8, 0.0, 0.0], color: Color.red },
      { position: Vec3[0.8, 0.0, 0.0], color: Color.green }
    ]
  )
end

def depth_vertices_far
  VertexBuffer.from_array(
    vertex_layout,
    [
      { position: Vec3[-0.8, 0.6, 0.9], color: Color.red },
      { position: Vec3[-0.6, -0.6, 0.9], color: Color.red },
      { position: Vec3[0.8, -0.6, 0.9], color: Color.red }
    ]
  )
end

def depth_vertices_near
  VertexBuffer.from_array(
    vertex_layout,
    [
      { position: Vec3[-0.2, 0.6, 0.1], color: Color.green },
      { position: Vec3[-0.4, -0.6, 0.1], color: Color.green },
      { position: Vec3[0.5, -0.6, 0.1], color: Color.green }
    ]
  )
end

def uv_vertices
  VertexBuffer.from_array(
    VertexLayout.new do
      attribute :position, 3
      attribute :uv, 2
      attribute :color, 4
    end,
    [
      { position: Vec3[-0.8, -0.8, 0], uv: Vec2[0, 1], color: Color.white },
      { position: Vec3[-0.8, 0.8, 0], uv: Vec2[0, 0], color: Color.white },
      { position: Vec3[0.8, -0.8, 0], uv: Vec2[1, 1], color: Color.white },
      { position: Vec3[0.8, 0.8, 0], uv: Vec2[1, 0], color: Color.white }
    ]
  )
end

def shaded_vertices
  VertexBuffer.from_array(
    vertex_layout,
    [
      { position: Vec3[-0.5, -0.5, 0.0], color: Color.red },
      { position: Vec3[0.0, 0.8, 0.0], color: Color.green },
      { position: Vec3[0.5, -0.5, 0.0], color: Color.blue }
    ]
  )
end

def report
  cases = {
    "framebuffer clear" => -> { clear_case },
    "triangle draw" => -> { triangle_case },
    "line draw" => -> { line_case },
    "depth test" => -> { depth_case },
    "texture sampling" => -> { texture_case },
    "shader call overhead" => -> { shader_call_overhead_case }
  }

  puts "Ruby #{RUBY_VERSION} (#{RUBY_PLATFORM})"
  puts "Iterations: #{ITERATIONS}"

  Benchmark.bm(22) do |bench|
    cases.each do |name, runner|
      bench.report(name) { runner.call }
    end
  end

  gc_alloc_case
end

report
