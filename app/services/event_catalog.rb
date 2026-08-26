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
  # "combat" rows are resolved by the player on their physical copy of the
  # game (this app never simulates combat — see the top of
  # docs/reference/deep-space-d6-mechanics.md); after the roll, the player
  # reports Victory or Defeat and the app applies the matching reward, same
  # pattern as the COMBAT: story events in events.yml. Defeat on an Open
  # Space roll means no reward, not game_over — unlike a scripted story
  # combat, there's no source text describing a harsher consequence for
  # losing a random encounter, so this is a deliberate conservative default.
  #
  # Zeta's combat rows (2-6) all carry the rulebook's "EE" (Endless Expansion)
  # icon — see docs/reference/deep-space-d6-mechanics.md and TODO.md's
  # "Expansion content flag". They still resolve (never silently skipped),
  # but are clearly labeled as requiring the Endless Expansion's own threat
  # deck, which we don't have card data for — see open_space_body.
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
      return normalize(stored, label) if stored

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
      stored ? normalize(stored, id) : nil
    end

    # Performs an explicit, player-triggered dice roll (the "Roll Dice"
    # button — see event_modal_controller.js) for the story-check patterns
    # below, and returns display text plus any resource deltas to apply.
    # Deliberately does NOT cover full combat/R&D — those stay on the
    # player's physical Deep Space D-6 copy; this is only for simple
    # story-driven checks the PDF calls for.
    def roll_dice_for(kind, label: nil, sector: nil, campaign: nil)
      case kind
      when "threat_die_table"
        roll_threat_die_table(label)
      when "open_space_chart"
        roll_open_space_chart(sector, campaign: campaign)
      end
    end

    private

    def normalize(data, label)
      choices = (data["choices"] || []).map { |c| c.slice("label", "action", "metadata") }
      result = {
        title: data["title"],
        body: data["body"].to_s.strip,
        choices: choices,
        resolvable: data.fetch("resolvable", true)
      }
      if data["threat_die_table"].present?
        result[:dice_roll] = { "kind" => "threat_die_table", "label" => label }
      elsif data["dice_roll"].present?
        result[:dice_roll] = data["dice_roll"]
      end
      result
    end

    def roll_threat_die_table(label)
      data = events[label]
      return { text: "" } unless data && data["threat_die_table"]

      roll = roll_die
      outcome = data["threat_die_table"][roll] || {}
      {
        text: "Threat die: #{roll} — #{outcome['text']}",
        scrap_delta: outcome["scrap_delta"].to_i,
        fuel_delta: outcome["fuel_delta"].to_i
      }
    end

    def roll_die
      rand(1..6)
    end

    def open_space_event(hex)
      {
        title: "Open Space",
        body: "Open space. Consult your scanners.",
        dice_roll: { "kind" => "open_space_chart", "sector" => hex["sector"] },
        choices: [ { "label" => "Return to Orbit", "action" => "orbit", "metadata" => {} } ],
        resolvable: false
      }
    end

    def roll_open_space_chart(sector, campaign: nil)
      chart = OPEN_SPACE_CHARTS[sector] || {}
      raw_roll = roll_die
      roll = raw_roll
      if campaign&.upgrade_researched?("lr_scanners")
        roll = [ raw_roll - 2, 1 ].max
      end
      outcome = chart[roll] || { type: "empty" }

      prefix = roll == raw_roll ? "" : "Long Range Scanners reduce the threat (rolled #{raw_roll} → #{roll}). "

      if outcome[:expansion].present?
        {
          text: prefix + endless_open_space_body(outcome),
          scrap_delta: 0,
          fuel_delta: 0,
          choices: [ { "label" => "Return to Orbit", "action" => "orbit", "metadata" => {} } ]
        }
      elsif outcome[:type] == "combat"
        {
          text: prefix + open_space_body(outcome),
          scrap_delta: 0,
          fuel_delta: 0,
          choices: [
            { "label" => "Victory — Return to Orbit", "action" => "orbit", "metadata" => { "scrap_delta" => outcome[:scrap].to_i } },
            { "label" => "Defeat — Return to Orbit", "action" => "orbit", "metadata" => {} }
          ]
        }
      else
        { text: prefix + open_space_body(outcome), scrap_delta: outcome[:scrap].to_i, fuel_delta: 0 }
      end
    end

    def open_space_body(outcome)
      case outcome[:type]
      when "combat"
        "Hostile contact — #{outcome[:threats]} threat(s), #{outcome[:deck]}-card wave. Resolve this on your " \
        "physical copy using the standard Threat deck, then report the outcome below."
      else
        outcome[:scrap] ? "#{EMPTY_FLAVOR.sample} Gain #{outcome[:scrap]} scrap." : EMPTY_FLAVOR.sample
      end
    end

    def endless_open_space_body(outcome)
      "Hostile contact — #{outcome[:threats]} threat(s), #{outcome[:deck]}-card wave. This is an ENDLESS EXPANSION " \
      "encounter: if you own the Endless Expansion, resolve it with the Endless threat deck (not the standard " \
      "deck). If you don't own the expansion, treat this as empty space — no encounter."
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
