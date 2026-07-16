# frozen_string_literal: true

require_relative "connection"
require_relative "pixel_encoder"

module RBGL
  module GUI
    module X11
      class Backend < GUI::Backend
        def initialize(width, height, title = "RBGL", env: ENV)
          super(width, height, title)
          @display = Connection.new(env["DISPLAY"] || ":0", env: env)
          @windows = {}
          setup_window(width, height, title)
        end

        private def setup_window(w, h, t)
          wid = @display.generate_id

          @display.create_window(
            depth: @display.root_depth,
            wid: wid,
            parent: @display.root,
            x: 0, y: 0,
            width: w, height: h,
            border_width: 0,
            window_class: :input_output,
            visual: @display.root_visual,
            value_mask: [:back_pixel, :event_mask],
            values: {
              back_pixel: @display.black_pixel,
              event_mask: [:exposure, :key_press, :key_release,
                           :button_press, :button_release, :pointer_motion,
                           :structure_notify]
            }
          )

          @display.change_property(wid, :wm_name, :string, t)
          @display.enable_wm_delete_window(wid)
          @display.map_window(wid)
          @display.flush

          gc_id = @display.generate_id
          @display.create_gc(gc_id, wid)

          @windows[wid] = {
            width: w,
            height: h,
            gc: gc_id,
            should_close: false
          }

          @handle = wid
        end

        def present(framebuffer)
          return false unless @handle

          window = @windows[@handle]
          return false unless window

          buffer = convert_to_x11_format(framebuffer)

          @display.put_image(
            format: :z_pixmap,
            drawable: @handle,
            gc: window[:gc],
            width: framebuffer.width,
            height: framebuffer.height,
            dst_x: 0, dst_y: 0,
            depth: @display.root_depth,
            data: buffer,
            bytes_per_line: pixel_encoder.bytes_per_line
          )

          @display.flush
          true
        end

        def poll_events
          events = []

          while @display.pending > 0
            raw_event = @display.next_event
            next unless raw_event

            event = convert_event(raw_event)
            events << event if event
          end

          events
        end

        def should_close?
          return false unless @handle

          @windows[@handle]&.[](:should_close) || false
        end

        def close
          return unless @handle

          @windows[@handle][:should_close] = true
          @display.destroy_window(@handle)
          @display.flush
          @windows.delete(@handle)
          @handle = nil
          @display.close
        end

        private

        def convert_to_x11_format(framebuffer)
          pixel_encoder.encode(framebuffer)
        end

        def pixel_encoder
          @pixel_encoder ||= PixelEncoder.new(
            bits_per_pixel: @display.bits_per_pixel,
            scanline_pad: @display.scanline_pad,
            visual_class: @display.visual_class,
            red_mask: @display.red_mask,
            green_mask: @display.green_mask,
            blue_mask: @display.blue_mask
          )
        end

        def convert_event(raw)
          case raw[:type]
          when :key_press
            Event.new(:key_press, key: @display.key_for_keycode(raw[:keycode]), keycode: raw[:keycode])
          when :key_release
            Event.new(:key_release, key: @display.key_for_keycode(raw[:keycode]), keycode: raw[:keycode])
          when :button_press
            Event.new(:mouse_press, x: raw[:x], y: raw[:y], button: raw[:button])
          when :button_release
            Event.new(:mouse_release, x: raw[:x], y: raw[:y], button: raw[:button])
          when :motion_notify
            Event.new(:mouse_move, x: raw[:x], y: raw[:y])
          when :configure_notify
            Event.new(:resize, width: raw[:width], height: raw[:height])
          when :client_message
            return nil unless raw[:window] == @handle
            return nil unless raw[:message_type] == @display.wm_protocols_atom
            return nil unless raw[:data32]&.first == @display.wm_delete_window_atom

            @windows[@handle][:should_close] = true if @handle && @windows[@handle]
            Event.new(:close)
          else
            nil
          end
        end
      end
    end
  end
end
