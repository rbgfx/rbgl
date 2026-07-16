# frozen_string_literal: true

module RBGL
  module GUI
    module X11
      class AtomCache
        BUILTIN_ATOMS = {
          wm_name: 39,
          string: 31,
          atom: 4
        }.freeze

        def initialize(&resolver)
          @resolver = resolver
          @cache = BUILTIN_ATOMS.dup
        end

        def fetch(name)
          return name if name.is_a?(Integer)
          return @cache[name] if @cache.key?(name)

          resolved = @resolver.call(name)
          @cache[name] = resolved unless resolved.zero?
          resolved
        end
      end
    end
  end
end
