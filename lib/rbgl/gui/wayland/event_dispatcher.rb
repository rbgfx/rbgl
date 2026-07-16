# frozen_string_literal: true

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
          return unless opcode == 0

          name = payload[0, 4].unpack1("V")
          interface_length = payload[4, 4].unpack1("V")
          interface = payload[8, interface_length - 1]
          version = payload[8 + @codec.pad_length(interface_length), 4].unpack1("V")
          @connection.store_global(interface, name: name, version: version)
        end

        def handle_xdg_wm_base_event(object, opcode, payload)
          return unless opcode == 0

          object.pong(payload.unpack1("V"))
          @connection.flush
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
