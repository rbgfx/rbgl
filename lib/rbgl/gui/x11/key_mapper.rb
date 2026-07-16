# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      module KeyMapper
        SPECIAL_KEYSYMS = {
          0xFF08 => :backspace,
          0xFF09 => :tab,
          0xFF0D => :enter,
          0xFF1B => :escape,
          0xFF50 => :home,
          0xFF51 => :left,
          0xFF52 => :up,
          0xFF53 => :right,
          0xFF54 => :down,
          0xFF55 => :page_up,
          0xFF56 => :page_down,
          0xFF57 => :end,
          0xFF63 => :insert,
          0xFFFF => :delete,
          0xFFE1 => :left_shift,
          0xFFE2 => :right_shift,
          0xFFE3 => :left_control,
          0xFFE4 => :right_control,
          0xFFE7 => :left_meta,
          0xFFE8 => :right_meta,
          0xFFE9 => :left_alt,
          0xFFEA => :right_alt
        }.merge((0xFFBE..0xFFC9).zip((1..12).map { |number| :"f#{number}" }).to_h).freeze

        DIGIT_NAMES = %i[zero one two three four five six seven eight nine].freeze

        module_function

        def key(keysym, fallback:)
          return fallback if keysym.nil? || keysym.zero?
          return SPECIAL_KEYSYMS[keysym] if SPECIAL_KEYSYMS.key?(keysym)
          return :space if keysym == 0x20
          return DIGIT_NAMES[keysym - 0x30] if keysym.between?(0x30, 0x39)
          return keysym.chr.downcase.to_sym if keysym.between?(0x41, 0x5A) || keysym.between?(0x61, 0x7A)

          fallback
        end
      end
    end
  end
end
