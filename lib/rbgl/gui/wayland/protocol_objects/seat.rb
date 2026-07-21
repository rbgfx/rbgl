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
          release(3, since: 5)
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
          @connection.register_object(Pointer.new(@connection, object_id, version: @version))
        end

        def create_keyboard
          object_id = @connection.allocate_id
          send_request(1, Arguments.new_id(object_id))
          @connection.register_object(Keyboard.new(@connection, object_id, version: @version))
        end
      end

      class Keyboard < WaylandObject
        attr_reader :focused_surface_id, :keymap, :keymap_format, :modifiers

        def initialize(...)
          super
          @modifiers = {}
        end

        def focus(surface_id)
          @focused_surface_id = surface_id
        end

        def blur
          @focused_surface_id = nil
        end

        def handle_keymap(format, size, io)
          raise GUI::BackendUnavailable, "Wayland keymap event did not include a file descriptor" unless io

          @keymap_format = { 0 => :none, 1 => :xkb_v1 }.fetch(format, format)
          @keymap = io.read(size)&.delete_suffix("\x00")
        ensure
          io&.close
        end

        def handle_modifiers(depressed:, latched:, locked:, group:)
          @modifiers = {
            depressed: depressed,
            latched: latched,
            locked: locked,
            group: group
          }
        end

        def destroy
          release(0, since: 3)
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
          release(1, since: 3)
        end
      end
    end
  end
end
