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
        attr_reader :id, :connection

        def initialize(connection, id)
          @connection = connection
          @id = id
        end

        def send_request(opcode, *args)
          @connection.send_request(@id, opcode, *args)
        end
      end
    end
  end
end
