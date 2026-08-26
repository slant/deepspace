# frozen_string_literal: true

class Campaign < ApplicationRecord
  DEFAULT_CARGO = "000-2-134711-182947-76123199-322521-8431364-L-M-Z".freeze
  START_HEX = { q: 2, r: 7 }.freeze
  PLANET_COUNT = 30
  PLANET_ICON_TYPES = %w[circle beacon_store].freeze

  belongs_to :user
  belongs_to :character, optional: true
  has_many :journal_entries, -> { order(created_at: :desc) }, dependent: :destroy

  enum :status, { draft: 0, active: 1, completed: 2, failed: 3 }

  validates :name, presence: true, if: :active?

  before_create :assign_public_id
  before_validation :ensure_defaults, on: :create

  def to_param
    public_id
  end

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

    transaction do
      generate_sector!(sector)
      update!(discovered_sectors: sectors + [ sector ])
    end
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
    assign_planet_sprites!
    discover_sector!(MapLoader.hex_at(ship_q, ship_r)["sector"]) if MapLoader.hex_at(ship_q, ship_r)
    log!("Campaign begun. Good luck, Captain #{character.name}.", entry_type: "milestone")
  end

  def assign_planet_sprites!
    planet_hexes = MapLoader.hexes.select { |h| h["icon"].in?(PLANET_ICON_TYPES) }
    indices = (0...PLANET_COUNT).to_a.sample(planet_hexes.size)
    sprites = planet_hexes.each_with_index.with_object({}) do |(hex, i), hash|
      hash["#{hex['q']},#{hex['r']}"] = indices[i]
    end
    update!(planet_sprites: sprites)
  end

  def planet_sprite_for(q, r)
    planet_sprites["#{q},#{r}"] || (q * 7 + r * 11).abs % PLANET_COUNT
  end

  def apply_resource_delta!(scrap_delta: 0, fuel_delta: 0)
    return if scrap_delta.zero? && fuel_delta.zero?
    update!(
      scrap: [scrap + scrap_delta, 0].max,
      fuel:  [fuel  + fuel_delta,  0].max
    )
  end

  # --- Items ---
  # items is an array of { "name" => String, "lost" => Boolean }. Re-gaining a
  # previously-lost item un-loses it rather than adding a duplicate entry.

  def has_item?(name)
    items.any? { |i| i["name"] == name && !i["lost"] }
  end

  def gain_item!(name)
    return if has_item?(name)

    updated = items.dup
    existing = updated.find { |i| i["name"] == name }
    if existing
      existing["lost"] = false
    else
      updated << { "name" => name, "lost" => false }
    end
    update!(items: updated)
    log!("Acquired [#{name}]", entry_type: "item")
  end

  def lose_item!(name)
    return unless has_item?(name)

    updated = items.dup
    updated.find { |i| i["name"] == name && !i["lost"] }["lost"] = true
    update!(items: updated)
    log!("Lost [#{name}]", entry_type: "item")
  end

  # --- Cargo sequence marks ---
  # cargo_marks maps a printed cargo token (e.g. "711", "L", "000") to
  # "underline" or "circle". Absence means unmarked.

  def sequence_state(token)
    cargo_marks[token]
  end

  def sequence_marked?(token)
    cargo_marks.key?(token)
  end

  def mark_sequence!(token, type)
    return if cargo_marks[token] == type

    update!(cargo_marks: cargo_marks.merge(token => type))
    log!("Marked sequence #{token} (#{type}d)", entry_type: "sequence")
  end

  def generate_sector!(sector)
    roll_count = MapLoader.sector_rolls[sector].to_i
    activated = activated_hexes.dup

    roll_count.times do
      roll = rand(1..12)
      hex = MapLoader.hex_for_roll(sector, roll)
      next unless hex
      key = "#{hex['q']},#{hex['r']}"
      next if activated.include?(key)
      activated << key
    end

    update!(activated_hexes: activated)
  end

  def hex_active?(q, r)
    activated_hexes.include?("#{q},#{r}")
  end

  def log!(body, entry_type: "note", metadata: {})
    journal_entries.create!(body: body, entry_type: entry_type, metadata: metadata)
  end

  private

  def assign_public_id
    loop do
      self.public_id = SecureRandom.alphanumeric(4)
      break unless Campaign.exists?(public_id: public_id)
    end
  end

  def ensure_defaults
    self.discovered_sectors ||= []
    self.researched_upgrades ||= {}
    self.resolved_events ||= []
    self.planet_sprites ||= {}
    self.activated_hexes ||= []
    self.fuel ||= 10
    self.scrap ||= 0
    self.draft_step ||= 1
    self.name ||= "New Campaign"
  end
end
