# frozen_string_literal: true

# Color Test - RGB verification
# Displays red, green, blue, and yellow squares

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"
require "rlsl"

WIDTH = 640
HEIGHT = 480

shader = RLSL.define(:color_test) do
  uniforms do
    float :time
  end

  # Pure Ruby DSL fragment shader
  # 4 quadrants: Top-left Red, Top-right Green, Bottom-left Blue, Bottom-right Yellow
  fragment do |frag_coord, resolution, _u|
    x = frag_coord.x / resolution.y
    y = frag_coord.y / resolution.y

    if x < 0.5 && y >= 0.5
      vec3(1.0, 0.0, 0.0)
    elsif x >= 0.5 && y >= 0.5
      vec3(0.0, 1.0, 0.0)
    elsif x < 0.5 && y < 0.5
      vec3(0.0, 0.0, 1.0)
    else
      vec3(1.0, 1.0, 0.0)
    end
  end
end

# Initialize display
window = RBGL::GUI::Window.new(width: WIDTH, height: HEIGHT, title: "Color Test")

puts "Color Test"
puts "Top-left: Red, Top-right: Green"
puts "Bottom-left: Blue, Bottom-right: Yellow"
puts "Press 'q' or Escape to quit"

running = true
buffer = "\x00" * (WIDTH * HEIGHT * 4)

while running && !window.should_close?
  shader.render(buffer, WIDTH, HEIGHT, { time: 0.0 })

  window.set_pixels(buffer)

  events = window.poll_events_raw
  events.each do |e|
    if e[:type] == :key_press && %i[escape q].include?(e[:key])
      running = false
    end
  end
end

window.close
