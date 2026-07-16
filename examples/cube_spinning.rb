# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"

include Larb
include RBGL::Engine

window = RBGL::GUI::Window.new(
  width: 320,
  height: 240,
  title: "Spinning Cube",
  backend: :auto
)

pipeline = Pipeline.create do
  vertex do |input, uniforms, output|
    output.position = uniforms.mvp * input.position.to_vec4
    output.color = input.color
  end

  fragment do |input, _uniforms, output|
    output.color = input.color
  end
end

def create_cube
  layout = VertexLayout.position_color
  buffer = VertexBuffer.new(layout)

  colors = [Color.red, Color.green, Color.blue, Color.yellow, Color.cyan, Color.magenta]

  faces = [
    [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]],
    [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]],
    [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]],
    [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]],
    [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]],
    [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]]
  ]

  faces.each_with_index do |face, i|
    color = colors[i]
    [[0, 1, 2], [0, 2, 3]].each do |tri|
      tri.each do |vi|
        pos = face[vi]
        buffer.add_vertex(
          position: Vec3[pos[0] * 0.5, pos[1] * 0.5, pos[2] * 0.5],
          color: color
        )
      end
    end
  end

  buffer
end

cube = create_cube
rotation = 0.0

view = Mat4.look_at(
  Vec3[0, 1, 3],
  Vec3[0, 0, 0],
  Vec3.up
)

window.on(:key_press) do |event|
  puts "Key pressed: #{event.key}"
  window.stop if %i[escape q].include?(event.key)
end

puts "Press 'q' or Escape to quit"

window.run do |ctx, dt|
  rotation += dt * 1.0

  model = Mat4.rotation_y(rotation) * Mat4.rotation_x(rotation * 0.7)
  projection = Mat4.perspective(Math::PI / 4, ctx.aspect_ratio, 0.1, 100)
  mvp = projection * view * model

  ctx.clear(color: Color.from_hex("#0f0f23"))
  ctx.bind_pipeline(pipeline)
  ctx.bind_vertex_buffer(cube)
  ctx.set_uniform(:mvp, mvp)
  ctx.draw_arrays(:triangles, 0, cube.vertex_count)
end
