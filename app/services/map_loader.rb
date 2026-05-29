# frozen_string_literal: true

# Loads starmap definition from config/map.yml
class MapLoader
  class << self
    def data
      @data ||= YAML.load_file(Rails.root.join("config/map.yml"))
    end

    def grid
      data["grid"]
    end

    def hexes
      data["hexes"]
    end

    def sector_rolls
      data["sectors"]&.transform_values { |v| v["rolls"] } || {}
    end

    def hex_size
      grid["hex_size"]
    end

    def orientation
      grid["orientation"]
    end

    def hex_index
      @hex_index ||= hexes.index_by { |h| [ h["q"], h["r"] ] }
    end

    def hex_at(q, r)
      hex_index[[ q, r ]]
    end

    def labeled_hexes
      hexes.select { |h| h["label"].present? }
    end

    def bounds
      xs = hexes.map { |h| HexGrid.axial_to_pixel(h["q"], h["r"], **grid_options).first }
      ys = hexes.map { |h| HexGrid.axial_to_pixel(h["q"], h["r"], **grid_options).last }
      padding = hex_size * 2
      { min_x: xs.min - padding, max_x: xs.max + padding,
        min_y: ys.min - padding, max_y: ys.max + padding }
    end

    def grid_options
      { size: hex_size, orientation: orientation }
    end

    def reload!
      @data = @hex_index = nil
    end

    def trigger_hexes_for_sector(sector)
      hexes.select { |h| h["sector"] == sector && h["trigger"].present? }
    end

    def parse_trigger(str)
      parts = str.split("-").map(&:to_i)
      parts.size == 1 ? [parts.first] : (parts.first..parts.last).to_a
    end

    def hex_for_roll(sector, roll)
      trigger_hexes_for_sector(sector).find { |h| parse_trigger(h["trigger"]).include?(roll) }
    end
  end
end
