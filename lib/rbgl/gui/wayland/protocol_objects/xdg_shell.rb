# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class XdgWmBase < WaylandObject
        def get_xdg_surface(surface)
          xdg_surface_id = @connection.allocate_id
          send_request(2, Arguments.new_id(xdg_surface_id), Arguments.object(surface))
          @connection.register_object(XdgSurface.new(@connection, xdg_surface_id))
        end

        def pong(serial)
          send_request(3, Arguments.uint(serial))
        end
      end

      class XdgSurface < WaylandObject
        def get_toplevel
          toplevel_id = @connection.allocate_id
          send_request(1, Arguments.new_id(toplevel_id))
          @connection.register_object(XdgToplevel.new(@connection, toplevel_id))
        end

        def ack_configure(serial)
          send_request(4, Arguments.uint(serial))
        end

        def destroy
          send_request(0)
        end
      end

      class XdgToplevel < WaylandObject
        def set_title(title)
          send_request(2, Arguments.string(title))
        end

        def destroy
          send_request(0)
        end
      end
    end
  end
end
