# frozen_string_literal: true

class Officer < ApplicationRecord
  TITLES = {
    commander: 0,
    lieutenant_commander: 1,
    lieutenant: 2,
    lieutenant_junior_grade: 3
  }.freeze

  # Fatigue threshold (event 43-A): default 4 X marks, 3 if WEAK/IMPULSIVE/
  # STUBBORN, 5 if OPTIMISTIC/IMPROVISER/PERSISTENT.
  LOW_FATIGUE_TRAITS = %w[weak impulsive stubborn].freeze
  HIGH_FATIGUE_TRAITS = %w[optimistic improviser persistent].freeze

  belongs_to :character

  enum :title, TITLES, validate: { allow_nil: true }

  validates :position, inclusion: { in: 0..3 }
  validates :name, :specialty, :attribute_a, :attribute_b, presence: true, if: :requires_details?

  def complete?
    name.present? && specialty.present? && attribute_a.present? && attribute_b.present? && title.present?
  end

  # --- Mutable in-play state ---
  # Locked character-creation fields (name/specialty/attribute_a/attribute_b)
  # never change once the character is locked. Permanent in-play changes from
  # events (gained attributes, death, title overrides like GLADIATOR) live in
  # these separate mutable fields instead.

  def effective_title
    title_override.presence || (title && title.titleize)
  end

  def all_attributes
    [ attribute_a, attribute_b, *bonus_attributes ].compact
  end

  def add_attribute!(name)
    return if bonus_attributes.include?(name)

    update!(bonus_attributes: bonus_attributes + [ name ])
  end

  def kill!
    update!(dead: true)
  end

  def fatigue_threshold
    traits = all_attributes.map { |a| a.to_s.downcase }
    return 3 if traits.any? { |t| LOW_FATIGUE_TRAITS.include?(t) }
    return 5 if traits.any? { |t| HIGH_FATIGUE_TRAITS.include?(t) }

    4
  end

  def fatigued?
    fatigue_marks >= fatigue_threshold
  end

  def add_fatigue_mark!
    increment!(:fatigue_marks)
  end

  private

  def requires_details?
    character&.locked?
  end
end
