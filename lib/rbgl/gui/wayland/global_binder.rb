# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class GlobalBinder
        BINDINGS = {
          "wl_compositor" => [:compositor, Compositor, 4],
          "wl_shm" => [:shm, Shm, 1],
          "xdg_wm_base" => [:xdg_wm_base, XdgWmBase, 2]
        }.freeze

        def initialize(connection)
          @connection = connection
        end

        def bind!(registry, globals)
          BINDINGS.each_with_object({}) do |(interface, binding), bound|
            slot, klass, max_version = binding
            global = globals[interface]
            next unless global

            object_id = registry.bind(global[:name], interface, [global[:version], max_version].min)
            bound[slot] = @connection.register_object(klass.new(@connection, object_id))
          end
        end
      end
    end
  end
end
