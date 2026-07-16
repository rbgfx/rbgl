# RBGL

RBGL (RuBy Graphics Library) is a pure Ruby software renderer with Cocoa, Wayland, X11, and headless file backends.

## Requirements

- Ruby 3.1 or newer
- macOS: the `metaco` gem for Cocoa windows
- Linux: a Wayland compositor or X11 server

## Installation

Add RBGL to your Gemfile:

```ruby
gem "rbgl"
```

Then run `bundle install`, or install it directly with `gem install rbgl`.

## Quick start

This complete example renders one triangle to `frames/frame_00000.ppm`. The file backend is useful for CI, image generation, and environments without a display server.

<!-- rbgl-doctest: file-triangle -->
```ruby
require "rbgl"

include Larb
include RBGL::Engine

window = RBGL::GUI::Window.new(
  width: 160,
  height: 120,
  backend: :file,
  output_dir: "frames",
  format: :ppm,
  max_frames: 1,
  target_fps: nil
)

pipeline = Pipeline.create do
  vertex do |input, _uniforms, output|
    output.position = input.position.to_vec4
    output.color = input.color
  end

  fragment do |input, _uniforms, output|
    output.color = input.color
  end
end
pipeline.cull_mode = :none

vertices = VertexBuffer.from_array(
  VertexLayout.position_color,
  [
    { position: Vec3[0.0, 0.7, 0.0], color: Color.red },
    { position: Vec3[-0.7, -0.7, 0.0], color: Color.green },
    { position: Vec3[0.7, -0.7, 0.0], color: Color.blue }
  ]
)

window.run do |context, _delta_time|
  context.clear(color: Color.from_hex("#101827"))
  context.bind_pipeline(pipeline)
  context.bind_vertex_buffer(vertices)
  context.draw_arrays(:triangles, 0, 3)
end
```

The same rendering code works in a native window by omitting the file-only options:

```ruby
window = RBGL::GUI::Window.new(
  width: 800,
  height: 600,
  title: "RBGL Triangle",
  backend: :auto
)
```

`:auto` chooses Cocoa on macOS and prefers Wayland before X11 on Linux. You can select `:cocoa`, `:wayland`, or `:x11` explicitly.

## Events

Register portable event handlers with `Window#on`. Keyboard events use symbols on every native backend.

```ruby
window.on(:key_press) do |event|
  window.stop if %i[escape q].include?(event.key)
end

window.on(:mouse_move) do |event|
  puts "Mouse: #{event.x}, #{event.y}"
end

window.on(:resize) do |event|
  puts "Size: #{event.width}x#{event.height}"
end
```

Supported portable event types include `:key_press`, `:key_release`, `:mouse_press`, `:mouse_release`, `:mouse_move`, `:resize`, and `:close`.

`Window#poll_events_raw` returns these normalized events as hashes when a manual loop is more convenient.

## Raw RGBA pixels

`Window#set_pixels` accepts exactly `width * height * 4` bytes in RGBA order and works with Cocoa, Wayland, X11, and the file backend:

```ruby
rgba = "\xFF\x00\x00\xFF" * (window.width * window.height)
window.set_pixels(rgba)
```

Metal compute support is an optional Cocoa capability. Check `window.metal_available?` before using `window.native_handle`; other backends return `false` and `nil` through the window facade.

## Render loop

The native render loop is capped at 60 fps by default. Set `target_fps: 30` to choose another limit or `target_fps: nil` to disable throttling. `window.fps` reports a moving one-second average, while `window.dropped_frames` counts rejected presents.

`Window#run` is intentionally one-shot: it closes its backend when the loop exits or raises. Create a new `Window` instead of calling `run` twice.

## File backend

The file backend creates `output_dir` automatically and stops after one frame by default.

```ruby
window = RBGL::GUI::Window.new(
  width: 320,
  height: 240,
  backend: :file,
  output_dir: "renders",
  format: :bmp,
  max_frames: 10
)
```

Supported formats are `:ppm` and `:bmp`. For PPM, select `ppm_mode: :ascii` or `ppm_mode: :binary`. Set `max_frames: nil` only when an unlimited output sequence is intentional.

## Examples and development

- `ruby examples/triangle_basic.rb` renders a PPM without opening a window.
- `ruby examples/triangle_window.rb` opens the portable native triangle demo.
- `ruby examples/cube_spinning.rb` renders an indexed 3D-style scene.
- `bundle exec rake test` runs the test suite and README doctest.
- `bundle exec rake lint` runs RuboCop correctness checks.
- `RBGL_BENCH_ITERATIONS=10 bundle exec ruby bench/renderer_bench.rb` runs renderer benchmarks.

Use `rbgl doctor` or `rbgl doctor --json` to inspect native backend availability.

## License

RBGL and the examples distributed in this repository are available under the [MIT License](LICENSE).
