# frozen_string_literal: true

class Officer < ApplicationRecord
  TITLES = {
    commander: 0,
    lieutenant_commander: 1,
    lieutenant: 2,
    lieutenant_junior_grade: 3
  }.freeze

  belongs_to :character

  enum :title, TITLES, validate: { allow_nil: true }

  validates :position, inclusion: { in: 0..3 }
  validates :name, :specialty, :attribute_a, :attribute_b, presence: true, if: :requires_details?

  def complete?
    name.present? && specialty.present? && attribute_a.present? && attribute_b.present? && title.present?
  end

  private

  def requires_details?
    character&.locked?
  end
end
