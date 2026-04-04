# frozen_string_literal: true

module RBGL
  module Engine
    class DynamicData
      def initialize(data = {})
        @data = {}
        data.to_h.each { |key, value| self[key] = value }
      end

      def method_missing(name, *args)
        if writer_method?(name)
          self[writer_key(name)] = args.first
        elsif args.empty? && @data.key?(normalize_key(name))
          self[name]
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        writer_method?(name) || @data.key?(normalize_key(name)) || super
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

      private

      def normalize_key(key)
        key.to_s.chomp("=").to_sym
      end

      def writer_method?(name)
        name.to_s.end_with?("=")
      end

      def writer_key(name)
        name.to_s.chomp("=").to_sym
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
