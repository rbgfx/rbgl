# frozen_string_literal: true

module RBGL
  module GUI
    module Wayland
      TypedArgument = Struct.new(:type, :value)

      module Arguments
        module_function

        def uint(value)
          TypedArgument.new(:uint, Integer(value))
        end

        def int(value)
          TypedArgument.new(:int, Integer(value))
        end

        def fixed(value)
          TypedArgument.new(:fixed, Float(value))
        end

        def string(value)
          TypedArgument.new(:string, value.to_s)
        end

        def object(value)
          object_id = value.respond_to?(:id) ? value.id : value
          TypedArgument.new(:object, Integer(object_id))
        end

        def new_id(value)
          TypedArgument.new(:new_id, Integer(value))
        end
      end

      class WaylandObject
        attr_reader :id, :connection, :version

        def initialize(connection, id, version: 1)
          @connection = connection
          @id = id
          @version = version
          @destroyed = false
        end

        def send_request(opcode, *args)
          @connection.send_request(@id, opcode, *args)
        end

        private

        def release(opcode, since: 1)
          return if @destroyed

          send_request(opcode) if @version >= since
          @connection.unregister_object(@id) if @connection.respond_to?(:unregister_object)
          @destroyed = true
        end
      end
    end
  end
end
