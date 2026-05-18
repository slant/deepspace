# frozen_string_literal: true

class HexMapComponent < ApplicationComponent
  def initialize(campaign:)
    @campaign = campaign
    @hexes = MapLoader.hexes
    @grid = MapLoader.grid
    @size = MapLoader.hex_size
    @orientation = MapLoader.orientation
    @bounds = MapLoader.bounds
    @edges = HexGrid.build_region_edges(@hexes, size: @size, orientation: @orientation)
    @offset_x = -@bounds[:min_x] + @size
    @offset_y = -@bounds[:min_y] + @size
    @width = @bounds[:max_x] - @bounds[:min_x] + @size * 2
    @height = @bounds[:max_y] - @bounds[:min_y] + @size * 2
  end

  private

  attr_reader :campaign, :hexes, :grid, :size, :orientation, :bounds, :edges,
              :offset_x, :offset_y, :width, :height

  def pixel_for(q, r)
    HexGrid.axial_to_pixel(q, r, size: size, orientation: orientation,
                           offset_x: offset_x, offset_y: offset_y)
  end

  def vertices_for(q, r)
    cx, cy = pixel_for(q, r)
    HexGrid.hex_vertices(cx, cy, size, orientation: orientation)
  end

  def points_string(verts)
    verts.map { |x, y| "#{x},#{y}" }.join(" ")
  end

  def ship_here?(hex)
    campaign.at_hex?(hex["q"], hex["r"])
  end

  def adjacent?(hex)
    campaign.adjacent_to?(hex["q"], hex["r"])
  end

  def resolved?(hex)
    label = hex["label"]
    label.present? && campaign.resolved_events.include?(label)
  end
end
