# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class Compositor < WaylandObject
        def create_surface
          surface_id = @connection.allocate_id
          send_request(0, Arguments.new_id(surface_id))
          @connection.register_object(Surface.new(@connection, surface_id))
        end
      end

      class Surface < WaylandObject
        def attach(buffer, x, y)
          send_request(1, Arguments.object(buffer), Arguments.int(x), Arguments.int(y))
        end

        def damage(x, y, width, height)
          send_request(2, Arguments.int(x), Arguments.int(y), Arguments.int(width), Arguments.int(height))
        end

        def commit
          send_request(6)
        end

        def destroy
          send_request(0)
        end
      end
    end
  end
end
