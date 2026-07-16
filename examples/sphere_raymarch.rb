# frozen_string_literal: true

# Raymarching Sphere - Native Shader DSL

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "rbgl"
require "rlsl"

WIDTH = 640
HEIGHT = 480

shader = RLSL.define(:raymarch) do
  uniforms do
    float :time
  end

  fragment do |frag_coord, resolution, u|
    uv = frag_coord / resolution.y

    # Ray origin (camera position)
    ro = vec3(0.0, 0.0, -3.0)

    # Ray direction
    centered = uv - vec2(0.5, 0.5)
    rd = normalize(vec3(centered.x, centered.y, 1.0))

    # Sphere center (animated)
    sphere_center = vec3(
      sin(u.time) * 0.5,
      cos(u.time * 0.7) * 0.3,
      0.0
    )
    sphere_radius = 0.8

    # Ray-sphere intersection
    oc = ro - sphere_center
    a = dot(rd, rd)
    b = 2.0 * dot(oc, rd)
    c = dot(oc, oc) - sphere_radius * sphere_radius
    discriminant = b * b - 4.0 * a * c

    if discriminant > 0.0
      t = (0.0 - b - sqrt(discriminant)) / (2.0 * a)
      if t > 0.0
        # Hit point
        hit = ro + rd * t

        # Normal at hit point
        normal = normalize(hit - sphere_center)

        # Light direction (animated)
        light_dir = normalize(vec3(
          sin(u.time * 0.5),
          1.0,
          cos(u.time * 0.3)
        ))

        # Diffuse lighting
        diff = clamp(dot(normal, light_dir), 0.0, 1.0)

        # Specular
        view_dir = rd * -1.0
        reflect_dir = normal * 2.0 * dot(normal, light_dir) - light_dir
        spec = pow(clamp(dot(view_dir, reflect_dir), 0.0, 1.0), 32.0)

        # Base color (hue shifts with time)
        base_color = vec3(
          0.5 + 0.5 * sin(u.time),
          0.5 + 0.5 * sin(u.time + 2.0),
          0.5 + 0.5 * sin(u.time + 4.0)
        )

        # Combine
        ambient = 0.1
        base_color * (ambient + diff * 0.7) + vec3(spec * 0.5, spec * 0.5, spec * 0.5)
      else
        # Behind camera
        vec3(0.05, 0.05, 0.1)
      end
    else
      # Background gradient
      t = uv.y
      mix(vec3(0.1, 0.1, 0.2), vec3(0.02, 0.02, 0.05), t)
    end
  end
end

# Initialize display
window = RBGL::GUI::Window.new(width: WIDTH, height: HEIGHT, title: "Raymarched Sphere")

puts "Raymarching Sphere - Native Shader DSL"
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
