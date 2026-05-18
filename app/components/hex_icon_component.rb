# frozen_string_literal: true

class HexIconComponent < ApplicationComponent
  def initialize(icon:, cx:, cy:, size:)
    @icon = icon
    @cx = cx
    @cy = cy
    @r = size * 0.28
  end

  private

  attr_reader :icon, :cx, :cy, :r
end
