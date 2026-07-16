# frozen_string_literal: true

module RBGL
  module GUI
    class Event
      attr_reader :type, :data

      def initialize(type, **data)
        @type = type
        @data = data
      end

      def [](key)
        @data[key]
      end

      def method_missing(name, *args, &block)
        return @data[name] if args.empty? && block.nil? && @data.key?(name)

        super
      end

      def respond_to_missing?(name, include_private = false)
        @data.key?(name) || super
      end

      def to_h
        { type: @type }.merge(@data)
      end

      def inspect
        "Event[#{@type}, #{@data.map { |k, v| "#{k}: #{v}" }.join(', ')}]"
      end
    end
  end
end
