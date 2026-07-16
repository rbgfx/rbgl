# frozen_string_literal: true

require_relative "version"
require_relative "gui/event"
require_relative "gui/backend"
require_relative "gui/backend_factory"
require_relative "gui/file_backend"
require_relative "gui/window"

module RBGL
  module GUI
    VERSION = RBGL::VERSION
  end
end
