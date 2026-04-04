# frozen_string_literal: true

module RBGL
  module Engine
    class ClipSpaceClipper
      CLIP_PLANES = [
        ->(position) { position.x + position.w },
        ->(position) { position.w - position.x },
        ->(position) { position.y + position.w },
        ->(position) { position.w - position.y },
        ->(position) { position.z + position.w },
        ->(position) { position.w - position.z }
      ].freeze

      def clip(v0, v1, v2)
        polygon = [v0, v1, v2]

        CLIP_PLANES.each do |plane|
          polygon = clip_against_plane(polygon, plane)
          return [] if polygon.empty?
        end

        triangulate(polygon)
      end

      def clip_line(v0, v1)
        segment = [duplicate_vertex(v0), duplicate_vertex(v1)]

        CLIP_PLANES.each do |plane|
          segment = clip_segment_against_plane(segment, plane)
          return nil unless segment
        end

        segment
      end

      def visible_point?(vertex)
        CLIP_PLANES.all? { |plane| signed_distance(vertex, plane) >= 0 }
      end

      private

      def clip_against_plane(vertices, plane)
        clipped = []
        return clipped if vertices.empty?

        previous_vertex = vertices.last
        previous_distance = signed_distance(previous_vertex, plane)

        vertices.each do |current_vertex|
          current_distance = signed_distance(current_vertex, plane)
          current_inside = current_distance >= 0
          previous_inside = previous_distance >= 0

          if current_inside != previous_inside
            clipped << interpolate_vertex(previous_vertex, current_vertex, previous_distance, current_distance)
          end

          clipped << duplicate_vertex(current_vertex) if current_inside

          previous_vertex = current_vertex
          previous_distance = current_distance
        end

        clipped
      end

      def triangulate(polygon)
        return [] if polygon.size < 3

        polygon[1..].each_cons(2).map do |v1, v2|
          [duplicate_vertex(polygon.first), duplicate_vertex(v1), duplicate_vertex(v2)]
        end
      end

      def clip_segment_against_plane(segment, plane)
        start_vertex, finish_vertex = segment
        start_distance = signed_distance(start_vertex, plane)
        finish_distance = signed_distance(finish_vertex, plane)
        start_inside = start_distance >= 0
        finish_inside = finish_distance >= 0

        return [start_vertex, finish_vertex] if start_inside && finish_inside
        return nil unless start_inside || finish_inside

        intersection = interpolate_vertex(start_vertex, finish_vertex, start_distance, finish_distance)
        start_inside ? [start_vertex, intersection] : [intersection, finish_vertex]
      end

      def interpolate_vertex(start_vertex, finish_vertex, start_distance, finish_distance)
        denominator = start_distance - finish_distance
        t = denominator.zero? ? 0.0 : start_distance / denominator
        result = ShaderIO.new

        interpolated_keys(start_vertex, finish_vertex).each do |key|
          start_value = start_vertex[key]
          finish_value = finish_vertex[key]
          result[key] = interpolate_value(start_value, finish_value, t)
        end

        result
      end

      def duplicate_vertex(vertex)
        ShaderIO.new(vertex.to_h)
      end

      def interpolated_keys(start_vertex, finish_vertex)
        (start_vertex.to_h.keys + finish_vertex.to_h.keys).uniq
      end

      def interpolate_value(start_value, finish_value, t)
        return finish_value if start_value.nil?
        return start_value if finish_value.nil?

        case start_value
        when Numeric
          start_value + (finish_value - start_value) * t
        when Larb::Vec2, Larb::Vec3, Larb::Vec4, Larb::Color
          start_value.lerp(finish_value, t)
        else
          t < 0.5 ? start_value : finish_value
        end
      end

      def signed_distance(vertex, plane)
        plane.call(clip_position(vertex))
      end

      def clip_position(vertex)
        position = vertex[:position]

        case position
        when Larb::Vec4 then position
        when Larb::Vec3 then Larb::Vec4.new(position.x, position.y, position.z, 1.0)
        when Larb::Vec2 then Larb::Vec4.new(position.x, position.y, 0.0, 1.0)
        else
          raise ArgumentError, "Unsupported clip position type: #{position.class}"
        end
      end
    end
  end
end
