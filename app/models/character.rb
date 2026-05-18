# frozen_string_literal: true

class Character < ApplicationRecord
  SHIP_TYPES = {
    halcyon: 0,
    athena_mk_ii: 1,
    ag_8: 2,
    mononoaware: 3
  }.freeze

  has_many :officers, -> { order(:position) }, dependent: :destroy
  has_one :campaign, dependent: :nullify
  accepts_nested_attributes_for :officers, allow_destroy: true

  enum :ship_type, SHIP_TYPES, validate: true

  validates :name, :ship_name, presence: true, if: :locked?
  validates :ship_type, presence: true, if: :locked?
  validate :four_officers_when_locked, if: :locked?

  def locked?
    locked_at.present?
  end

  def lock!
    update!(locked_at: Time.current)
  end

  private

  def four_officers_when_locked
    return if officers.size == 4 && officers.all?(&:complete?)

    errors.add(:base, "Four fully configured officers are required")
  end
end
