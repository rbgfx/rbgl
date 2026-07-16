# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      module InputMapper
        KEY_NAMES = {
          1 => :escape,
          14 => :backspace,
          15 => :tab,
          28 => :enter,
          29 => :left_control,
          42 => :left_shift,
          54 => :right_shift,
          56 => :left_alt,
          57 => :space,
          58 => :caps_lock,
          87 => :f11,
          88 => :f12,
          97 => :right_control,
          100 => :right_alt,
          102 => :home,
          103 => :up,
          104 => :page_up,
          105 => :left,
          106 => :right,
          107 => :end,
          108 => :down,
          109 => :page_down,
          110 => :insert,
          111 => :delete,
          125 => :left_meta,
          126 => :right_meta
        }.merge(
          (2..10).zip(%i[one two three four five six seven eight nine]).to_h,
          { 11 => :zero },
          (16..25).zip(%i[q w e r t y u i o p]).to_h,
          (30..38).zip(%i[a s d f g h j k l]).to_h,
          (44..50).zip(%i[z x c v b n m]).to_h,
          (59..68).zip(%i[f1 f2 f3 f4 f5 f6 f7 f8 f9 f10]).to_h
        ).freeze

        POINTER_BUTTONS = {
          0x110 => 1,
          0x111 => 3,
          0x112 => 2
        }.freeze

        module_function

        def key(code)
          KEY_NAMES.fetch(code, code)
        end

        def button(code)
          POINTER_BUTTONS.fetch(code, code)
        end
      end
    end
  end
end
