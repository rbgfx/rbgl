# frozen_string_literal: true

module RBGL
  module Engine
    class ImmutableColor < Larb::Color
      def self.from(color)
        return color if color.is_a?(self)
        unless color.is_a?(Larb::Color)
          raise ArgumentError, "Colors must be Larb::Color values"
        end

        new(color.r, color.g, color.b, color.a).freeze
      end

      def r=(_value)
        raise FrozenError, "stored colors are immutable"
      end

      def g=(_value)
        raise FrozenError, "stored colors are immutable"
      end

      def b=(_value)
        raise FrozenError, "stored colors are immutable"
      end

      def a=(_value)
        raise FrozenError, "stored colors are immutable"
      end
    end
  end
end
