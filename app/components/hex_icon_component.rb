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

  # public/planets.png is 500x600px: 5 columns x 6 rows of 100px cells (30 cells,
  # only the first 25 are used). It is NOT square, so the <image> width/height
  # must preserve that 5:6 aspect ratio or SVG's default "meet" scaling will
  # letterbox/offset it, misaligning every cell's clip.
  SHEET_COLS = 5
  SHEET_ROWS = 6

  def planet_x(center_x = cx, cell = pd) = center_x - cell / 2.0 - planet_col * cell
  def planet_y(center_y = cy, cell = pd) = center_y - cell / 2.0 - planet_row * cell
  def planet_sheet_width(cell = pd) = cell * SHEET_COLS
  def planet_sheet_height(cell = pd) = cell * SHEET_ROWS
  def clip_id(suffix = "") = "planet-clip-#{cx.round}-#{cy.round}#{suffix}"
end
