# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class Seat < WaylandObject
        POINTER_CAPABILITY = 1
        KEYBOARD_CAPABILITY = 2

        attr_reader :keyboard, :pointer

        def handle_capabilities(capabilities)
          update_pointer(capabilities & POINTER_CAPABILITY != 0)
          update_keyboard(capabilities & KEYBOARD_CAPABILITY != 0)
        end

        def destroy
          @pointer&.destroy
          @keyboard&.destroy
          send_request(3)
        end

        private

        def update_pointer(available)
          @pointer ||= create_pointer if available
          return if available || !@pointer

          @pointer.destroy
          @pointer = nil
        end

        def update_keyboard(available)
          @keyboard ||= create_keyboard if available
          return if available || !@keyboard

          @keyboard.destroy
          @keyboard = nil
        end

        def create_pointer
          object_id = @connection.allocate_id
          send_request(0, Arguments.new_id(object_id))
          @connection.register_object(Pointer.new(@connection, object_id))
        end

        def create_keyboard
          object_id = @connection.allocate_id
          send_request(1, Arguments.new_id(object_id))
          @connection.register_object(Keyboard.new(@connection, object_id))
        end
      end

      class Keyboard < WaylandObject
        attr_reader :focused_surface_id

        def focus(surface_id)
          @focused_surface_id = surface_id
        end

        def blur
          @focused_surface_id = nil
        end

        def destroy
          send_request(0)
        end
      end

      class Pointer < WaylandObject
        attr_reader :focused_surface_id, :x, :y

        def focus(surface_id)
          @focused_surface_id = surface_id
        end

        def blur
          @focused_surface_id = nil
        end

        def move(x, y)
          @x = x
          @y = y
        end

        def destroy
          send_request(1)
        end
      end
    end
  end
end
