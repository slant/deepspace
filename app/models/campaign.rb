# frozen_string_literal: true

class Campaign < ApplicationRecord
  DEFAULT_CARGO = "000-2-134711-182947-76123199-322521-8431364-L-M-Z".freeze
  START_HEX = { q: 2, r: 7 }.freeze

  belongs_to :user
  belongs_to :character, optional: true
  has_many :journal_entries, -> { order(created_at: :desc) }, dependent: :destroy

  enum :status, { draft: 0, active: 1, completed: 2 }

  validates :name, presence: true, if: :active?

  before_validation :ensure_defaults, on: :create

  def progress_summary
    return "Character creation" if draft?

    parts = []
    parts << "Fuel #{fuel}"
    parts << "Scrap #{scrap}"
    parts << "At #{current_hex_label}" if ship_q && ship_r
    parts.join(" · ")
  end

  def display_name
    character&.name.presence || name.presence || "New Campaign"
  end

  def current_hex_label
    hex = MapLoader.hex_at(ship_q, ship_r)
    hex&.dig("label") || "#{ship_q},#{ship_r}"
  end

  def at_hex?(q, r)
    ship_q == q && ship_r == r
  end

  def adjacent_to?(q, r)
    HexGrid.adjacent?(ship_q, ship_r, q, r)
  end

  def can_move_to?(q, r)
    return false unless active?
    return false unless adjacent_to?(q, r)
    return false if fuel <= 0

    true
  end

  def move_to!(q, r)
    raise ArgumentError, "Invalid move" unless can_move_to?(q, r)

    transaction do
      update!(ship_q: q, ship_r: r, fuel: fuel - 1)
      log!("Moved to #{MapLoader.hex_at(q, r)&.dig('label') || "#{q},#{r}"}", entry_type: "movement")
    end
  end

  def resolve_event!(label)
    resolved = resolved_events.dup
    resolved << label unless resolved.include?(label)
    update!(resolved_events: resolved)
    log!("Resolved event #{label}", entry_type: "event")
  end

  def discover_sector!(sector)
    sectors = discovered_sectors.dup
    return if sectors.include?(sector)

    update!(discovered_sectors: sectors + [ sector ])
    log!("Entered #{sector.titleize} sector", entry_type: "sector")
  end

  def activate!
    raise "Character required" unless character&.locked?

    update!(
      status: :active,
      ship_q: START_HEX[:q],
      ship_r: START_HEX[:r],
      cargo_sequence: DEFAULT_CARGO,
      name: "#{character.name} — #{character.ship_name}"
    )
    discover_sector!(MapLoader.hex_at(ship_q, ship_r)["sector"]) if MapLoader.hex_at(ship_q, ship_r)
    log!("Campaign begun. Good luck, Captain #{character.name}.", entry_type: "milestone")
  end

  def log!(body, entry_type: "note", metadata: {})
    journal_entries.create!(body: body, entry_type: entry_type, metadata: metadata)
  end

  private

  def ensure_defaults
    self.discovered_sectors ||= []
    self.researched_upgrades ||= {}
    self.resolved_events ||= []
    self.fuel ||= 10
    self.scrap ||= 0
    self.draft_step ||= 1
    self.name ||= "New Campaign"
  end
end
