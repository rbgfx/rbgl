# frozen_string_literal: true

require "socket"

module RBGL
  module GUI
    module X11
      class XAuthority
        FAMILY_INTERNET = 0
        FAMILY_LOCAL = 256
        FAMILY_WILD = 65_535
        AUTH_NAME = "MIT-MAGIC-COOKIE-1"

        Entry = Struct.new(:family, :address, :display, :name, :data, keyword_init: true)

        def self.cookie_for(host:, display_number:, env: ENV)
          path = env["XAUTHORITY"] || default_path(env)
          return nil unless path && File.file?(path)

          new(File.binread(path)).cookie_for(host: host, display_number: display_number)
        rescue ArgumentError, EOFError
          nil
        end

        def self.default_path(env)
          home = env["HOME"] || Dir.home
          File.join(home, ".Xauthority")
        rescue ArgumentError
          nil
        end

        def initialize(data)
          @entries = parse(data)
        end

        def cookie_for(host:, display_number:)
          candidates = @entries.select do |entry|
            entry.display == display_number.to_s && entry.name == AUTH_NAME
          end
          candidates.find { |entry| address_matches?(entry, host) }&.data
        end

        private

        def parse(data)
          offset = 0
          entries = []

          while offset < data.bytesize
            family, offset = read_u16(data, offset)
            address, offset = read_field(data, offset)
            display, offset = read_field(data, offset)
            name, offset = read_field(data, offset)
            cookie, offset = read_field(data, offset)
            entries << Entry.new(family: family, address: address, display: display, name: name, data: cookie)
          end

          entries
        end

        def read_u16(data, offset)
          bytes = data.byteslice(offset, 2)
          raise EOFError, "Truncated Xauthority entry" unless bytes&.bytesize == 2

          [bytes.unpack1("n"), offset + 2]
        end

        def read_field(data, offset)
          length, offset = read_u16(data, offset)
          value = data.byteslice(offset, length)
          raise EOFError, "Truncated Xauthority field" unless value&.bytesize == length

          [value, offset + length]
        end

        def address_matches?(entry, host)
          return true if entry.family == FAMILY_WILD
          return local_address_matches?(entry.address) if host.nil? && entry.family == FAMILY_LOCAL
          return false unless entry.family == FAMILY_INTERNET

          Addrinfo.getaddrinfo(host, nil, :INET).any? do |address|
            address.ip_address.split(".").map(&:to_i).pack("C4") == entry.address
          end
        rescue SocketError
          false
        end

        def local_address_matches?(address)
          address.empty? || address == Socket.gethostname
        end
      end
    end
  end
end
