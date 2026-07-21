# frozen_string_literal: true

require_relative "input_mapper"

module RBGL
  module GUI
    module Wayland
      class EventDispatcher
        def initialize(connection, codec:)
          @connection = connection
          @codec = codec
        end

        def handle_event(object_id, opcode, payload)
          object = @connection.object_for(object_id)

          case object
          when Display
            handle_display_event(opcode, payload)
          when Registry
            handle_registry_event(opcode, payload)
          when Callback
            object.handle_done if opcode == 0
          when WlBuffer
            object.handle_release if opcode == 0
          when Seat
            object.handle_capabilities(payload.unpack1("V")) if opcode == 0
          when Keyboard
            handle_keyboard_event(object, opcode, payload)
          when Pointer
            handle_pointer_event(object, opcode, payload)
          when XdgWmBase
            handle_xdg_wm_base_event(object, opcode, payload)
          when XdgSurface
            object.handle_configure(payload.unpack1("V")) if opcode == 0
          when XdgToplevel
            handle_xdg_toplevel_event(object_id, opcode, payload)
          end
        end

        private

        def handle_display_event(opcode, payload)
          case opcode
          when 0
            failed_object, code, length = payload.byteslice(0, 12).unpack("VVV")
            message = payload.byteslice(12, length - 1)
            raise GUI::BackendUnavailable,
                  "Wayland protocol error #{code} on object #{failed_object}: #{message}"
          when 1
            @connection.unregister_object(payload.unpack1("V"))
          end
        end

        def handle_registry_event(opcode, payload)
          case opcode
          when 0
            name = payload[0, 4].unpack1("V")
            interface_length = payload[4, 4].unpack1("V")
            interface = payload[8, interface_length - 1]
            version = payload[8 + @codec.pad_length(interface_length), 4].unpack1("V")
            @connection.store_global(interface, name: name, version: version)
          when 1
            @connection.remove_global(payload.unpack1("V"))
          end
        end

        def handle_xdg_wm_base_event(object, opcode, payload)
          return unless opcode == 0

          object.pong(payload.unpack1("V"))
          @connection.flush
        end

        def handle_keyboard_event(keyboard, opcode, payload)
          case opcode
          when 0
            format, size = payload.unpack("V2")
            keyboard.handle_keymap(format, size, @connection.consume_received_fd)
          when 1
            keyboard.focus(payload.byteslice(4, 4).unpack1("V"))
          when 2
            keyboard.blur
          when 3
            _serial, _time, keycode, state = payload.unpack("V4")
            event = {
              type: state == 1 ? :key_press : :key_release,
              surface_id: keyboard.focused_surface_id,
              key: InputMapper.key(keycode),
              keycode: keycode
            }
            event[:modifiers] = keyboard.modifiers.dup unless keyboard.modifiers.empty?
            @connection.queue_event(event)
          when 4
            _serial, depressed, latched, locked, group = payload.unpack("V5")
            keyboard.handle_modifiers(
              depressed: depressed,
              latched: latched,
              locked: locked,
              group: group
            )
          end
        end

        def handle_pointer_event(pointer, opcode, payload)
          case opcode
          when 0
            _serial, surface_id, x, y = payload.unpack("VVl<l<")
            pointer.focus(surface_id)
            queue_pointer_motion(pointer, x, y)
          when 1
            pointer.blur
          when 2
            _time, x, y = payload.unpack("Vl<l<")
            queue_pointer_motion(pointer, x, y)
          when 3
            _serial, _time, button, state = payload.unpack("V4")
            @connection.queue_event(
              type: state == 1 ? :pointer_button_press : :pointer_button_release,
              surface_id: pointer.focused_surface_id,
              button: InputMapper.button(button),
              x: pointer.x,
              y: pointer.y
            )
          when 4
            _time, axis, value = payload.unpack("VVl<")
            @connection.queue_event(
              type: :pointer_axis,
              surface_id: pointer.focused_surface_id,
              axis: { 0 => :vertical, 1 => :horizontal }.fetch(axis, axis),
              value: value / 256.0,
              x: pointer.x,
              y: pointer.y
            )
          end
        end

        def queue_pointer_motion(pointer, fixed_x, fixed_y)
          pointer.move(fixed_x / 256.0, fixed_y / 256.0)
          @connection.queue_event(
            type: :pointer_motion,
            surface_id: pointer.focused_surface_id,
            x: pointer.x,
            y: pointer.y
          )
        end

        def handle_xdg_toplevel_event(object_id, opcode, payload)
          case opcode
          when 0
            width, height = payload[0, 8].unpack("l<l<")
            @connection.queue_event(
              type: :xdg_toplevel_configure,
              object_id: object_id,
              width: width,
              height: height
            )
          when 1
            @connection.queue_event(type: :xdg_toplevel_close, object_id: object_id)
          end
        end
      end
    end
  end
end
