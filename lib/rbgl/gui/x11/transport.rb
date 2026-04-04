# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      class Transport
        attr_reader :socket

        def initialize(socket)
          @socket = socket
        end

        def write(data)
          @socket.write(data)
        end

        def read(length)
          @socket.read(length)
        end

        def flush
          @socket.flush
        end

        def pending
          IO.select([@socket], nil, nil, 0) ? 1 : 0
        end
      end
    end
  end
end
