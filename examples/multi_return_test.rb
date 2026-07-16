# frozen_string_literal: true

# Multiple Return Value Test Shader
# Tests Ruby-mode multiple return value support in RLSL

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"
require "rlsl"

WIDTH = 640
HEIGHT = 480

shader = RLSL.define(:multi_return_test) do
  uniforms do
    float :time
  end

  functions do
    # Function that returns multiple values (tuple)
    define :compute_basis, returns: [:vec3, :vec3], params: { n: :vec3 }
  end

  helpers do
    # Function returning multiple values as an array
    def compute_basis(n)
      # Orthonormal basis calculation
      a = 1.0 / (1.0 + n.z + 0.0001)
      b = n.y * a
      c = 0.0 - n.x * a
      xp = vec3(n.z + b, c, 0.0 - n.x)
      yp = vec3(c, 1.0 - b, 0.0 - n.y)
      [xp, yp]
    end
  end

  fragment do |frag_coord, resolution, u|
    uv = vec2(
      (frag_coord.x - resolution.x * 0.5) / resolution.y,
      (frag_coord.y - resolution.y * 0.5) / resolution.y
    )

    # Create a normal from UV coordinates
    t = u.time * 0.5
    n = normalize(vec3(uv.x + sin(t), uv.y + cos(t), 1.0))

    # Get basis vectors using multiple return values
    tang, binorm = compute_basis(n)

    # Visualize the basis vectors
    r = abs(tang.x) * 0.5 + 0.5
    g = abs(binorm.y) * 0.5 + 0.5
    b = abs(n.z) * 0.5 + 0.5

    vec3(r, g, b)
  end
end

# Initialize display
window = RBGL::GUI::Window.new(width: WIDTH, height: HEIGHT, title: "Multi Return Test")

puts "Multiple Return Value Test Shader"
puts "Tests Ruby-mode multiple return value support"
puts "Press 'q' or Escape to quit"

start_time = Time.now
frame_count = 0
last_fps_time = start_time
running = true

buffer = "\x00" * (WIDTH * HEIGHT * 4)

while running && !window.should_close?
  time = Time.now - start_time

  shader.render(buffer, WIDTH, HEIGHT, { time: time })

  window.set_pixels(buffer)

  events = window.poll_events_raw
  events.each do |e|
    case e[:type]
    when :key_press
      running = false if %i[escape q].include?(e[:key])
    end
  end

  frame_count += 1
  now = Time.now
  if now - last_fps_time >= 1.0
    fps = frame_count / (now - last_fps_time)
    puts "FPS: #{fps.round(1)}"
    frame_count = 0
    last_fps_time = now
  end
end

window.close
