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

          @cache[name] ||= @resolver.call(name)
        end
      end
    end
  end
end
