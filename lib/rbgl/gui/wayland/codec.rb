# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class Codec
        def pack_args(args)
          result = String.new

          args.each do |arg|
            case arg
            when TypedArgument
              result << pack_typed_argument(arg)
            when Integer
              result << [arg].pack("V")
            when String
              result << pack_string(arg)
            when Float
              result << [(arg * 256).to_i].pack("V")
            end
          end

          result
        end

        def pad_length(length)
          ((length + 3) / 4) * 4
        end

        private

        def pack_typed_argument(argument)
          case argument.type
          when :uint, :object, :new_id
            [argument.value].pack("V")
          when :int
            [argument.value].pack("l<")
          when :fixed
            [(argument.value * 256).round].pack("l<")
          when :string
            pack_string(argument.value)
          else
            raise ArgumentError, "Unsupported Wayland argument type: #{argument.type}"
          end
        end

        def pack_string(value)
          length = value.bytesize + 1
          [length].pack("V") + value + "\x00" + ("\x00" * ((4 - length % 4) % 4))
        end
      end
    end
  end
end
