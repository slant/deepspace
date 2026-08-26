# frozen_string_literal: true

# Axial hex coordinate math (pointy-top and flat-top)
class HexGrid
  DIRECTIONS = [ [ 1, 0 ], [ 1, -1 ], [ 0, -1 ], [ -1, 0 ], [ -1, 1 ], [ 0, 1 ] ].freeze

  class << self
    def axial_to_pixel(q, r, size:, orientation: "pointy-top", offset_x: 0, offset_y: 0)
      if orientation == "pointy-top"
        x = size * Math.sqrt(3) * (q + r / 2.0)
        y = size * 1.5 * r
      else
        x = size * 1.5 * q
        y = size * Math.sqrt(3) * (r + q / 2.0)
      end
      [ x + offset_x, y + offset_y ]
    end

    def hex_vertices(cx, cy, size, orientation: "pointy-top")
      start_angle = orientation == "pointy-top" ? -30 : 0
      (0...6).map do |i|
        angle = (Math::PI / 180) * (start_angle + 60 * i)
        [ cx + size * Math.cos(angle), cy + size * Math.sin(angle) ]
      end
    end

    def adjacent?(q1, r1, q2, r2)
      DIRECTIONS.any? { |dq, dr| q1 + dq == q2 && r1 + dr == r2 }
    end

    def distance(q1, r1, q2, r2)
      ((q1 - q2).abs + (q1 + r1 - q2 - r2).abs + (r1 - r2).abs) / 2
    end

    def neighbor(q, r, dir)
      dq, dr = DIRECTIONS[dir]
      [ q + dq, r + dr ]
    end

    def neighbor_dir_to_edge_index(dir)
      (6 - dir) % 6
    end

    def build_region_edges(hexes, size:, orientation:, offset_x: 0, offset_y: 0)
      hex_map = hexes.index_by { |h| [ h["q"], h["r"] ] }
      edges = {}

      hexes.each do |hex|
        q, r = hex["q"], hex["r"]
        region_a = hex["sector"] || "default"
        cx, cy = axial_to_pixel(q, r, size: size, orientation: orientation, offset_x: offset_x, offset_y: offset_y)
        verts = hex_vertices(cx, cy, size, orientation: orientation)

        6.times do |dir|
          nq, nr = neighbor(q, r, dir)
          neighbor_hex = hex_map[[ nq, nr ]]
          region_b = neighbor_hex&.dig("sector") || "default"
          edge_index = neighbor_dir_to_edge_index(dir)
          a = verts[edge_index]
          b = verts[(edge_index + 1) % 6]
          key = edge_key(a, b)
          type = (!neighbor_hex || region_a != region_b) ? "boundary" : "internal"
          existing = edges[key]
          if existing.nil?
            edges[key] = { a: a, b: b, type: type }
          elsif type == "internal" || existing[:type] == "internal"
            existing[:type] = "internal"
          end
        end
      end

      edges.values
    end

    private

    def edge_key(a, b)
      a_key = "#{a[0].round(2)},#{a[1].round(2)}"
      b_key = "#{b[0].round(2)},#{b[1].round(2)}"
      a_key < b_key ? "#{a_key}-#{b_key}" : "#{b_key}-#{a_key}"
    end
  end
end
