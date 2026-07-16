# frozen_string_literal: true

# Simple gradient shader to verify Metal pipeline works

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"
require "rlsl"

WIDTH = 640
HEIGHT = 480

# Define a simple Metal shader using pure Ruby DSL
shader = RLSL.define_metal(:metal_test) do
  uniforms do
    float :time
  end

  fragment do |frag_coord, resolution, u|
    p = frag_coord / resolution

    r = 0.5 + 0.5 * sin(p.x * 10.0 + u.time)
    g = 0.5 + 0.5 * sin(p.y * 10.0 + u.time * 1.3)
    b = 0.5 + 0.5 * sin((p.x + p.y) * 10.0 + u.time * 0.7)

    vec3(r, g, b)
  end
end

puts "Generated MSL source:"
puts "-" * 40
puts shader.msl_source
puts "-" * 40

# Initialize display
window = RBGL::GUI::Window.new(width: WIDTH, height: HEIGHT, title: "Metal Test")

puts "Metal Test - Gradient Shader"
puts "Press 'q' or Escape to quit"

# Check Metal availability
if window.metal_available?
  puts "Metal compute is available!"
else
  puts "Metal compute is NOT available"
  exit 1
end

start_time = Time.now
frame_count = 0
last_fps_time = start_time
running = true

while running && !window.should_close?
  time = Time.now - start_time

  begin
    shader.render_metal(window.native_handle, WIDTH, HEIGHT, { time: time })
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace.first(5).join("\n")
    running = false
    break
  end

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
