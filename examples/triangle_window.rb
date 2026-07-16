# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"

include Larb
include RBGL::Engine

window = RBGL::GUI::Window.new(
  width: 320,
  height: 240,
  title: "Hello Triangle - Window",
  backend: :auto
)

pipeline = Pipeline.create do
  vertex do |input, uniforms, output|
    angle = uniforms.time || 0
    pos = input.position

    rotated_x = pos.x * Math.cos(angle) - pos.y * Math.sin(angle)
    rotated_y = pos.x * Math.sin(angle) + pos.y * Math.cos(angle)

    output.position = Vec4[rotated_x, rotated_y, pos.z, 1.0]
    output.color = input.color
  end

  fragment do |input, _uniforms, output|
    output.color = input.color
  end
end

layout = VertexLayout.position_color
vertices = VertexBuffer.from_array(layout, [
  { position: Vec3[0.0, 0.5, 0.0], color: Color.red },
  { position: Vec3[-0.5, -0.5, 0.0], color: Color.green },
  { position: Vec3[0.5, -0.5, 0.0], color: Color.blue }
])

time = 0.0

window.on(:key_press) do |event|
  puts "Key: #{event.key}"
  window.stop if %i[escape q].include?(event.key)
end

window.on(:mouse_move) do |event|
  puts "Mouse: #{event.x}, #{event.y}" if event.x && event.y
end

puts "Spinning triangle - Press 'q' or Escape to quit"

window.run do |ctx, dt|
  time += dt

  ctx.clear(color: Color.from_hex("#1a1a2e"))
  ctx.bind_pipeline(pipeline)
  ctx.bind_vertex_buffer(vertices)
  ctx.set_uniform(:time, time)
  ctx.draw_arrays(:triangles, 0, 3)
end
