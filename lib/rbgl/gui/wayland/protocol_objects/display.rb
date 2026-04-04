# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class Display < WaylandObject
        def initialize(connection)
          super(connection, 1)
        end

        def sync
          callback_id = @connection.allocate_id
          send_request(0, Arguments.new_id(callback_id))
          @connection.register_object(Callback.new(@connection, callback_id))
        end

        def get_registry
          registry_id = @connection.allocate_id
          send_request(1, Arguments.new_id(registry_id))
          @connection.register_object(Registry.new(@connection, registry_id))
        end
      end

      class Registry < WaylandObject
        def bind(name, interface, version)
          new_id = @connection.allocate_id
          send_request(
            0,
            Arguments.uint(name),
            Arguments.string(interface),
            Arguments.uint(version),
            Arguments.new_id(new_id)
          )
          new_id
        end
      end

      class Callback < WaylandObject
        def initialize(connection, id)
          super
          @done = false
        end

        def done?
          @done
        end

        def handle_done
          @done = true
        end
      end
    end
  end
end
