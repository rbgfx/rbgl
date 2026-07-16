# frozen_string_literal: true

require_relative "version"
require_relative "engine/immutable_color"
require_relative "engine/framebuffer"
require_relative "engine/buffer"
require_relative "engine/shader"
require_relative "engine/texture"
require_relative "engine/rasterizer"
require_relative "engine/pipeline"
require_relative "engine/clip_space_clipper"
require_relative "engine/context"

module RBGL
  module Engine
    VERSION = RBGL::VERSION
  end
end
