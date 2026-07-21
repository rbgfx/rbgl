# frozen_string_literal: true

require "socket"
require "ipaddr"

module RBGL
  module GUI
    module X11
      class XAuthority
        FAMILY_INTERNET = 0
        FAMILY_INTERNET6 = 6
        FAMILY_LOCAL = 256
        FAMILY_WILD = 65_535
        AUTH_NAME = "MIT-MAGIC-COOKIE-1"

        Entry = Struct.new(:family, :address, :display_number, :name, :data, keyword_init: true)

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
            (entry.display_number.empty? || entry.display_number == display_number.to_s) && entry.name == AUTH_NAME
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
            display_number, offset = read_field(data, offset)
            name, offset = read_field(data, offset)
            cookie, offset = read_field(data, offset)
            entries << Entry.new(
              family: family,
              address: address,
              display_number: display_number,
              name: name,
              data: cookie
            )
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
          return false unless [FAMILY_INTERNET, FAMILY_INTERNET6].include?(entry.family)

          family = entry.family == FAMILY_INTERNET ? :INET : :INET6
          Addrinfo.getaddrinfo(host, nil, family).any? do |address|
            IPAddr.new(address.ip_address).hton == entry.address
          end
        rescue SocketError
          false
        end

        def local_address_matches?(address)
          return true if address.empty?

          expected = address.downcase
          actual = Socket.gethostname.downcase
          expected == actual || expected.split(".", 2).first == actual.split(".", 2).first
        end
      end
    end
  end
end
