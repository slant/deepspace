# frozen_string_literal: true

class EventCatalog
  EMPTY_FLAVOR = [
    "Empty space. Nothing on scanners.",
    "Empty space. The void is quiet.",
    "Empty space. Drift and watch.",
    "Empty space. A moment to breathe.",
    "Empty space. Stars stretch endlessly.",
    "Empty space. No contacts."
  ].freeze

  # Open Space Encounter Chart (PDF page 8). Roll a d6 on entering a blank hex.
  # "combat" rows can't run real combat yet (priority #10 — no Hull/Shield
  # tracking exists on Campaign at all), so they resolve as an automatic,
  # unharmed win: any listed scrap reward is still granted, but no damage is
  # simulated since there's nothing to apply it to. Replace with real combat
  # resolution once that system exists.
  #
  # Zeta's combat rows (2-6) all carry the rulebook's "EE" (Endless Expansion)
  # icon — see docs/reference/deep-space-d6-mechanics.md. We have no real
  # Endless card data, so they're treated as ignored/Empty for every player
  # regardless of expansion ownership, per TODO.md "Expansion content flag".
  OPEN_SPACE_CHARTS = {
    "alpha" => {
      1 => { type: "empty" }, 2 => { type: "empty" }, 3 => { type: "empty" }, 4 => { type: "empty" },
      5 => { type: "combat", threats: 2, deck: 5 },
      6 => { type: "combat", threats: 2, deck: 5, scrap: 2 }
    },
    "beta" => {
      1 => { type: "empty" }, 2 => { type: "empty" },
      3 => { type: "empty", scrap: 3 },
      4 => { type: "combat", threats: 2, deck: 4 },
      5 => { type: "combat", threats: 3, deck: 2, scrap: 3 },
      6 => { type: "combat", threats: 3, deck: 5 }
    },
    "delta" => {
      1 => { type: "empty" }, 2 => { type: "empty" },
      3 => { type: "combat", threats: 2, deck: 6, scrap: 3 },
      4 => { type: "combat", threats: 4, deck: 5, scrap: 3 },
      5 => { type: "combat", threats: 2, deck: 6, scrap: 4 },
      6 => { type: "combat", threats: 4, deck: 5, scrap: 5 }
    },
    "zeta" => {
      1 => { type: "empty" },
      2 => { type: "combat", threats: 3, deck: 0, expansion: "endless" },
      3 => { type: "combat", threats: 2, deck: 5, expansion: "endless" },
      4 => { type: "combat", threats: 2, deck: 5, expansion: "endless" },
      5 => { type: "combat", threats: 3, deck: 6, expansion: "endless" },
      6 => { type: "combat", threats: 4, deck: 7, expansion: "endless" }
    },
    "tau" => {}
  }.freeze

  class << self
    def for_hex(hex, campaign:)
      label = hex["label"]
      return open_space_event(hex) if label.blank?

      stored = events[label]
      return normalize(stored) if stored

      default_event(label, hex)
    end

    def events
      @events ||= begin
        path = Rails.root.join("config/events.yml")
        File.exist?(path) ? YAML.load_file(path) : {}
      end
    end

    def for_event(id)
      stored = events[id]
      stored ? normalize(stored) : nil
    end

    private

    # Generic support for a single-roll-then-choose event shape (e.g. 22-A):
    # roll a plain threat die once, append the rolled outcome's text to the
    # body, and merge its scrap_delta/fuel_delta into every choice (so
    # whichever path the player picks afterward still carries the roll's
    # consequence). Declared in events.yml as a `threat_die_table` hash of
    # roll (1-6) => { "text" =>, "scrap_delta" =>, "fuel_delta" => }.
    def normalize(data)
      body = data["body"].to_s.strip
      choices = (data["choices"] || []).map { |c| c.slice("label", "action", "metadata") }

      if data["threat_die_table"].present?
        roll = roll_die
        outcome = data["threat_die_table"][roll] || {}
        body = [ body, "Threat die: #{roll} — #{outcome['text']}" ].reject(&:blank?).join("\n\n")
        choices = choices.map { |choice| apply_die_outcome(choice, outcome) }
      end

      {
        title: data["title"],
        body: body,
        choices: choices,
        resolvable: data.fetch("resolvable", true)
      }
    end

    def apply_die_outcome(choice, outcome)
      metadata = (choice["metadata"] || {}).dup
      metadata["scrap_delta"] = metadata.fetch("scrap_delta", 0).to_i + outcome["scrap_delta"].to_i if outcome["scrap_delta"]
      metadata["fuel_delta"] = metadata.fetch("fuel_delta", 0).to_i + outcome["fuel_delta"].to_i if outcome["fuel_delta"]
      choice.merge("metadata" => metadata)
    end

    def roll_die
      rand(1..6)
    end

    def open_space_event(hex)
      chart = OPEN_SPACE_CHARTS[hex["sector"]] || {}
      roll = roll_die
      outcome = chart[roll] || { type: "empty" }
      # Expansion-gated (Zeta) combat rows: no real Endless card data, so
      # treat as ignored/Empty for everyone until that content exists.
      outcome = { type: "empty" } if outcome[:expansion].present?

      {
        title: "Open Space",
        body: open_space_body(outcome),
        choices: [
          {
            "label" => "Return to Orbit",
            "action" => "orbit",
            "metadata" => outcome[:scrap] ? { "scrap_delta" => outcome[:scrap] } : {}
          }
        ],
        resolvable: false
      }
    end

    def open_space_body(outcome)
      case outcome[:type]
      when "combat"
        parts = [ "Hostile contact — #{outcome[:threats]} threat(s), #{outcome[:deck]}-card wave. " \
                  "Your crew scrambles to stations and fights it off without incident." ]
        parts << "Gain #{outcome[:scrap]} scrap." if outcome[:scrap]
        parts.join(" ")
      else
        outcome[:scrap] ? "#{EMPTY_FLAVOR.sample} Gain #{outcome[:scrap]} scrap." : EMPTY_FLAVOR.sample
      end
    end

    def default_event(label, hex)
      icon = hex["icon"]
      kind = case icon
             when "circle" then "beacon"
             when "square" then "store"
             when "beacon_store" then "beacon & store"
             when "home" then "homeworld"
             when "jump" then "jump point"
             else "space"
             end
      {
        title: label,
        body: "Sector #{hex['sector']&.titleize}: #{kind.titleize} at #{label}. " \
              "See event #{label} in the rulebook (PDF in /public).",
        choices: [
          { "label" => "Mark resolved & return to orbit", "action" => "resolve" },
          { "label" => "Return to orbit", "action" => "orbit" }
        ],
        resolvable: icon.in?(%w[circle square beacon_store home])
      }
    end
  end
end
