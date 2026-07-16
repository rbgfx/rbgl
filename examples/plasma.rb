# frozen_string_literal: true

# Classic Plasma Effect using Native Shader DSL

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"
require "rlsl"

WIDTH = 640
HEIGHT = 480

# Define plasma shader using pure Ruby DSL
shader = RLSL.define(:plasma) do
  uniforms do
    float :time
  end

  fragment do |frag_coord, resolution, u|
    uv = frag_coord / resolution.y
    cx = uv.x - 0.5
    cy = uv.y - 0.5

    v1 = sin(cx * 10.0 + u.time)
    v2 = sin(10.0 * (cx * sin(u.time / 2.0) + cy * cos(u.time / 3.0)) + u.time)

    cx2 = cx + 0.5 * sin(u.time / 5.0)
    cy2 = cy + 0.5 * cos(u.time / 3.0)
    v3 = sin(sqrt(100.0 * (cx2 * cx2 + cy2 * cy2) + 1.0) + u.time)

    v = v1 + v2 + v3

    r = sin(v * PI)
    g = sin(v * PI + 2.0 * PI / 3.0)
    b = sin(v * PI + 4.0 * PI / 3.0)

    vec3((r + 1.0) * 0.5, (g + 1.0) * 0.5, (b + 1.0) * 0.5)
  end
end

# Initialize display
window = RBGL::GUI::Window.new(width: WIDTH, height: HEIGHT, title: "Plasma Effect")

puts "Plasma Effect - Native Shader DSL"
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
    if e[:type] == :key_press && %i[escape q].include?(e[:key])
      running = false
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
