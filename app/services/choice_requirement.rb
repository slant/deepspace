# frozen_string_literal: true

# Evaluates a choice's `requires` metadata (officer specialty/attribute,
# items, cargo sequence marks) against a campaign's current state. Requires
# structured metadata authored directly on the choice in events.yml — never
# parses [Requires: ...] label text at runtime, matching the project's
# existing scrap_delta/fuel_delta convention.
#
# Supported requirement keys (all optional, combined with AND):
#   specialty_or_attribute: ["HACKER"]           — any officer has any of these
#                                                    (specialty, attribute_a, or
#                                                    attribute_b), case-insensitive
#   excludes_specialty_or_attribute: ["COWARD"]  — no officer has any of these
#   item: "AI-System"                             — campaign has this item, not lost
#   items_all: ["Lux Food", "Fluffy Creature"]    — has all of these items
#   sequence: "711"                                — token is marked (any state)
#   sequence: "Z", state: "underlined"             — token marked in this state
#                                                    ("underlined" or "circled")
#   sequence_all: ["L", "711"]                     — all tokens marked (any state)
#   exclude_sequence: "711"                        — token is NOT marked
#   exclude_sequence_any: ["L", "711"]             — none of these are marked
class ChoiceRequirement
  STATE_ALIASES = { "underlined" => "underline", "circled" => "circle" }.freeze

  class << self
    def satisfied?(requires, campaign:)
      return true if requires.blank?

      requires = requires.stringify_keys
      requires.keys.all? { |key| check(key, requires, campaign) }
    end

    private

    def check(key, requires, campaign)
      case key
      when "specialty_or_attribute"
        officer_has_any?(campaign, requires["specialty_or_attribute"])
      when "excludes_specialty_or_attribute"
        !officer_has_any?(campaign, requires["excludes_specialty_or_attribute"])
      when "item"
        campaign.has_item?(requires["item"])
      when "items_all"
        Array(requires["items_all"]).all? { |name| campaign.has_item?(name) }
      when "sequence"
        sequence_satisfied?(requires, campaign)
      when "state"
        true # consumed together with "sequence" above
      when "sequence_all"
        Array(requires["sequence_all"]).all? { |token| campaign.sequence_marked?(token) }
      when "exclude_sequence"
        !campaign.sequence_marked?(requires["exclude_sequence"])
      when "exclude_sequence_any"
        Array(requires["exclude_sequence_any"]).none? { |token| campaign.sequence_marked?(token) }
      else
        true
      end
    end

    def sequence_satisfied?(requires, campaign)
      token = requires["sequence"]
      wanted_state = requires["state"]
      return campaign.sequence_marked?(token) unless wanted_state

      campaign.sequence_state(token) == (STATE_ALIASES[wanted_state] || wanted_state)
    end

    def officer_has_any?(campaign, names)
      officers = campaign.character&.officers || []
      wanted = Array(names).map { |n| n.to_s.downcase }
      officers.any? do |officer|
        [ officer.specialty, officer.attribute_a, officer.attribute_b ].any? do |trait|
          trait.present? && wanted.include?(trait.to_s.downcase)
        end
      end
    end
  end
end
