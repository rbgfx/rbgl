# frozen_string_literal: true

require "io/wait"

module RBGL
  module GUI
    module X11
      class Transport
        READ_CHUNK_SIZE = 16_384

        attr_reader :socket

        def initialize(socket)
          @socket = socket
          @read_buffer = String.new(encoding: Encoding::BINARY)
        end

        def write(data)
          @socket.write(data)
        end

        def read(length)
          read_exact(length)
        end

        def read_exact(length, timeout: nil)
          fill_buffer(length, timeout: timeout)
          @read_buffer.slice!(0, length)
        end

        def flush
          @socket.flush
        end

        def pending
          read_available
          @read_buffer.empty? ? 0 : 1
        end

        def close
          @socket.close unless @socket.closed?
        end

        private

        def fill_buffer(length, timeout:)
          deadline = timeout && (monotonic_time + timeout)

          while @read_buffer.bytesize < length
            wait = deadline && [deadline - monotonic_time, 0].max
            raise IO::EAGAINWaitReadable unless @socket.wait_readable(wait)

            read_available
          end
        end

        def read_available
          return unless @socket.wait_readable(0)

          loop do
            chunk = @socket.read_nonblock(READ_CHUNK_SIZE, exception: false)
            break if chunk == :wait_readable
            raise EOFError, "X11 server closed the connection" if chunk.nil?

            @read_buffer << chunk
          end
        end

        def monotonic_time
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
      end
    end
  end
end
