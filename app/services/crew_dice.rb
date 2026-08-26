# frozen_string_literal: true

# The 6 physical crew dice (per the game's own dice, confirmed against a
# photo of the physical set — not printed anywhere in the Long Way Home
# PDF, which assumes ownership of the base game). Each of the 6 dice is
# identical: one face per result below, so a roll is uniform 1/6 per face.
# There is no skull face — a previous session guessed "skull" for an icon
# pdftotext couldn't extract; see docs/reference/events-yaml-pdf-deviations.md.
class CrewDice
  FACES = %w[threat_detected commander science engineering tactical medical].freeze

  def self.roll(count)
    Array.new(count) { FACES.sample }
  end
end
