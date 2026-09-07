# Changelog

## Unreleased

- Fixed perspective depth interpolation, shared-edge coverage, NPOT mipmaps, repeat filtering, and shader numeric edge cases.
- Fixed native window resize, close, and Wayland disconnect handling, including internal size synchronization during raw event polling.
- Tightened vertex layout, index, draw-range, and texture data mutation contracts, and skipped unnecessary clipping and expired frame deadlines.

## 1.0.0 - 2026-04-05

- Removed the legacy `Window#on_key`, `Window#on_mouse`, and `Window#on_resize` aliases. Register handlers with `window.on(:key_press)`, `window.on(:mouse_move)`, `window.on(:resize)`, and the other event types directly.
- Removed the legacy `backend: :native` alias. Use `backend: :auto` for automatic native backend selection.
- Changed file backend binary PPM output to `format: :ppm, ppm_mode: :binary`. The old `format: :ppm_binary` option is no longer accepted.
- Added a runtime dependency on `rlsl`, so existing applications need it resolved during install and bundle steps.
- Added binary (`P6`) and text (`P3`) PPM texture loading via `RBGL::Engine::Texture.from_ppm`, and added ASCII or binary PPM output selection for the file backend.
- Added `RBGL::GUI::Window#dropped_frames` so applications can detect failed presents, including Wayland backpressure cases.
- Improved automatic native backend selection on Linux: RBGL now prefers Wayland when available, falls back to X11 when needed, and raises clearer `BackendUnavailable` errors when no display server can be used.
- Improved rendering correctness with view-frustum clipping for triangles, lines, and points, perspective-correct interpolation, point rasterization fixes, and pipeline render-state handling.
- Tightened validation across pipelines, shaders, vertex buffers, textures, sampler settings, mipmaps, and texture writes so invalid rendering inputs fail earlier with explicit errors.

## 0.1.0 - 2026-01-04

- Initial release.
