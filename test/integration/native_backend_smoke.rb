# frozen_string_literal: true

require "rbgl"

backend_name = ENV.fetch("RBGL_SMOKE_BACKEND").to_sym
backend = nil
begin
  backend = RBGL::GUI::BackendFactory.build(
    backend_name,
    width: 64,
    height: 48,
    title: "RBGL native smoke test"
  )
  framebuffer = RBGL::Engine::Framebuffer.new(64, 48)
  framebuffer.clear(color: Larb::Color.rgb(0.2, 0.4, 0.8))

  raise "#{backend_name} failed to present a frame" unless backend.present(framebuffer)

  backend.poll_events
  puts "#{backend_name} backend smoke test passed"
ensure
  backend&.close
end
