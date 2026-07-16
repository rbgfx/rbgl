# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      class EventParser
        def parse(data)
          return nil unless data && data.bytesize == 32

          event_type = data.unpack1("C") & 0x7F

          case event_type
          when 2
            key_event(:key_press, data)
          when 3
            key_event(:key_release, data)
          when 4
            button_event(:button_press, data)
          when 5
            button_event(:button_release, data)
          when 6
            x, y = data[24, 4].unpack("s<s<")
            { type: :motion_notify, x: x, y: y }
          when 12
            { type: :exposure }
          when 22
            width, height = data[20, 4].unpack("vv")
            { type: :configure_notify, width: width, height: height }
          when 33
            {
              type: :client_message,
              format: data[1, 1].unpack1("C"),
              window: data[4, 4].unpack1("V"),
              message_type: data[8, 4].unpack1("V"),
              data32: data[12, 20].unpack("V5")
            }
          else
            { type: :unknown, code: event_type }
          end
        end

        private

        def key_event(type, data)
          { type: type, keycode: data[1, 1].unpack1("C") }
        end

        def button_event(type, data)
          x, y = data[24, 4].unpack("s<s<")
          {
            type: type,
            x: x,
            y: y,
            button: data[1, 1].unpack1("C")
          }
        end
      end
    end
  end
end
