# frozen_string_literal: true

module RBGL
  module GUI
    module Cocoa
      module KeyMapper
        KEY_CODES = {
          0 => :a, 1 => :s, 2 => :d, 3 => :f, 4 => :h, 5 => :g, 6 => :z, 7 => :x,
          8 => :c, 9 => :v, 11 => :b, 12 => :q, 13 => :w, 14 => :e, 15 => :r,
          16 => :y, 17 => :t, 18 => :one, 19 => :two, 20 => :three, 21 => :four,
          22 => :six, 23 => :five, 24 => :equal, 25 => :nine, 26 => :seven,
          27 => :minus, 28 => :eight, 29 => :zero, 30 => :right_bracket, 31 => :o,
          32 => :u, 33 => :left_bracket, 34 => :i, 35 => :p, 36 => :enter, 37 => :l,
          38 => :j, 39 => :quote, 40 => :k, 41 => :semicolon, 42 => :backslash,
          43 => :comma, 44 => :slash, 45 => :n, 46 => :m, 47 => :period, 48 => :tab,
          49 => :space, 50 => :grave, 51 => :backspace, 53 => :escape, 54 => :right_meta,
          55 => :left_meta, 56 => :left_shift, 57 => :caps_lock, 58 => :left_alt,
          59 => :left_control, 60 => :right_shift, 61 => :right_alt, 62 => :right_control,
          63 => :function, 64 => :f17, 65 => :keypad_decimal, 67 => :keypad_multiply,
          69 => :keypad_plus, 71 => :keypad_clear, 72 => :volume_up, 73 => :volume_down,
          74 => :mute, 75 => :keypad_divide, 76 => :keypad_enter, 78 => :keypad_minus,
          79 => :f18, 80 => :f19, 81 => :keypad_equal, 82 => :keypad_zero,
          83 => :keypad_one, 84 => :keypad_two, 85 => :keypad_three, 86 => :keypad_four,
          87 => :keypad_five, 88 => :keypad_six, 89 => :keypad_seven,
          91 => :keypad_eight, 92 => :keypad_nine, 96 => :f5, 97 => :f6, 98 => :f7,
          99 => :f3, 100 => :f8, 101 => :f9, 103 => :f11, 105 => :f13,
          106 => :f16, 107 => :f14, 109 => :f10, 111 => :f12, 113 => :f15,
          114 => :help, 115 => :home, 116 => :page_up, 117 => :delete,
          118 => :f4, 119 => :end, 120 => :f2, 121 => :page_down, 122 => :f1,
          123 => :left, 124 => :right, 125 => :down, 126 => :up
        }.freeze

        module_function

        def key(code, char = nil)
          return code if code.is_a?(Symbol)
          return KEY_CODES.fetch(code, code) if code.is_a?(Integer)

          text = char.to_s.empty? ? code.to_s : char.to_s
          return :escape if text == "\e" || text.casecmp?("escape")
          return text.downcase.to_sym if text.length == 1

          code
        end
      end
    end
  end
end
