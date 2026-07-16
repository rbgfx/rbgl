# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      class Codec
        def pack_args(args)
          result = String.new

          args.each do |arg|
            unless arg.is_a?(TypedArgument)
              raise ArgumentError, "Wayland requests require typed arguments"
            end

            result << pack_typed_argument(arg)
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
