# frozen_string_literal: true

class EventCatalog
  OPEN_SPACE = {
    "1" => "Empty space. Nothing on scanners.",
    "2" => "Empty space. The void is quiet.",
    "3" => "Empty space. Drift and watch.",
    "4" => "Empty space. A moment to breathe.",
    "5" => "Empty space. Stars stretch endlessly.",
    "6" => "Empty space. No contacts."
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

    private

    def normalize(data)
      {
        title: data["title"],
        body: data["body"].to_s.strip,
        choices: (data["choices"] || []).map { |c| c.slice("label", "action", "metadata") },
        resolvable: data.fetch("resolvable", true)
      }
    end

    def open_space_event(hex)
      note = hex["note"].to_s
      roll = note.include?("-") ? note.split("-").first : note
      text = OPEN_SPACE[roll] || "Open space. Consult the encounter chart on page 8 of the rulebook."
      {
        title: "Open Space",
        body: text,
        choices: [ { "label" => "Return to Orbit", "action" => "orbit" } ],
        resolvable: false
      }
    end

    def default_event(label, hex)
      icon = hex["icon"]
      kind = case icon
             when "circle" then "beacon"
             when "square" then "store"
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
        resolvable: icon.in?(%w[circle square home])
      }
    end
  end
end
