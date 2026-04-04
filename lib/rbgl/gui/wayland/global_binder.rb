# frozen_string_literal: true

require_relative "../backend"

module RBGL
  module GUI
    module Wayland
      class GlobalBinder
        BINDINGS = {
          "wl_compositor" => [:compositor, Compositor, 4],
          "wl_shm" => [:shm, Shm, 1],
          "xdg_wm_base" => [:xdg_wm_base, XdgWmBase, 2]
        }.freeze
        REQUIRED_INTERFACES = BINDINGS.keys.freeze

        def initialize(connection)
          @connection = connection
        end

        def bind!(registry, globals)
          validate_required_globals!(globals)

          BINDINGS.each_with_object({}) do |(interface, binding), bound|
            slot, klass, max_version = binding
            global = globals[interface]
            next unless global

            object_id = registry.bind(global[:name], interface, [global[:version], max_version].min)
            bound[slot] = @connection.register_object(klass.new(@connection, object_id))
          end
        end

        private

        def validate_required_globals!(globals)
          missing = REQUIRED_INTERFACES - globals.keys
          return if missing.empty?

          raise GUI::BackendUnavailable, "Wayland globals missing: #{missing.join(', ')}"
        end
      end
    end
  end
end
