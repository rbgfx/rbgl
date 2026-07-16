# frozen_string_literal: true

# Array Test Shader
# Tests the Ruby-mode array support in RLSL

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"
require "rlsl"

WIDTH = 640
HEIGHT = 480

shader = RLSL.define(:array_test) do
  uniforms do
    float :time
  end

  functions do
    define :get_color, returns: :vec3, params: { i: :int }
  end

  # Helper functions in Ruby mode with arrays
  helpers do
    # Color palette as an array
    COLORS = [
      vec3(1.0, 0.0, 0.0),  # Red
      vec3(0.0, 1.0, 0.0),  # Green
      vec3(0.0, 0.0, 1.0),  # Blue
      vec3(1.0, 1.0, 0.0)   # Yellow
    ]

    def get_color(i)
      COLORS[i]
    end
  end

  fragment do |frag_coord, resolution, u|
    uv = vec2(frag_coord.x / resolution.x, frag_coord.y / resolution.y)

    # Pick color based on quadrant
    qx = 0
    qy = 0
    if uv.x > 0.5
      qx = 1
    end
    if uv.y > 0.5
      qy = 2
    end

    idx = qx + qy
    color = get_color(idx)

    # Add some animation
    t = sin(u.time) * 0.5 + 0.5
    vec3(color.x * t + 0.2, color.y * t + 0.2, color.z * t + 0.2)
  end
end

# Initialize display
window = RBGL::GUI::Window.new(width: WIDTH, height: HEIGHT, title: "Array Test")

puts "Array Test Shader"
puts "Tests Ruby-mode array support"
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
