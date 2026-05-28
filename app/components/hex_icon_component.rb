# frozen_string_literal: true

class HexIconComponent < ApplicationComponent
  def initialize(icon:, cx:, cy:, size:, planet_index: 0)
    @icon = icon
    @cx = cx
    @cy = cy
    @size = size
    @r = size * 0.28
    @planet_col = planet_index % 5
    @planet_row = planet_index / 5
    @pd = size * 0.65
  end

  private

  attr_reader :icon, :cx, :cy, :r, :size, :planet_col, :planet_row, :pd

  def planet_x(center_x = cx, cell = pd) = center_x - cell / 2.0 - planet_col * cell
  def planet_y(center_y = cy, cell = pd) = center_y - cell / 2.0 - planet_row * cell
  def planet_sheet_size(cell = pd) = cell * 5
  def clip_id(suffix = "") = "planet-clip-#{cx.round}-#{cy.round}#{suffix}"
end
