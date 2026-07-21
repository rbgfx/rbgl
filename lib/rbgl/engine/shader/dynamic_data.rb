# frozen_string_literal: true

module RBGL
  module Engine
    class DynamicData
      def initialize(data = {})
        @data = {}
        @writer_keys = {}
        data.to_h.each { |key, value| self[key] = value }
      end

      def method_missing(name, *args)
        key = normalize_key(name)
        if args.empty? && @data.key?(key)
          @data[key]
        elsif (writer = writer_key(name))
          self[writer] = args.first
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        @data.key?(normalize_key(name)) || !writer_key(name).nil? || super
      end

      def [](key)
        @data[normalize_key(key)]
      end

      def []=(key, value)
        @data[normalize_key(key)] = value
      end

      def to_h
        @data.dup
      end

      def keys
        @data.keys
      end

      def clear
        @data.clear
        self
      end

      private

      def normalize_key(key)
        return key if key.is_a?(Symbol)

        key.to_s.chomp("=").to_sym
      end

      def writer_key(name)
        return @writer_keys[name] if @writer_keys.key?(name)

        text = name.to_s
        @writer_keys[name] = text.end_with?("=") ? text.chomp("=").to_sym : nil
      end
    end

    class ShaderIO < DynamicData
    end

    class Uniforms < DynamicData
      def merge(other)
        Uniforms.new(@data.merge(other.to_h))
      end
    end
  end
end
