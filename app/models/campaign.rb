# frozen_string_literal: true

class Campaign < ApplicationRecord
  DEFAULT_CARGO = "000-2-134711-182947-76123199-322521-8431364-L-M-Z".freeze
  START_HEX = { q: 2, r: 7 }.freeze
  PLANET_COUNT = 25
  PLANET_ICON_TYPES = %w[circle beacon_store].freeze

  belongs_to :user
  belongs_to :character, optional: true
  has_many :journal_entries, -> { order(created_at: :desc) }, dependent: :destroy

  enum :status, { draft: 0, active: 1, completed: 2 }

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

    generate_sector!(sector)
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
    assign_planet_sprites!
    discover_sector!(MapLoader.hex_at(ship_q, ship_r)["sector"]) if MapLoader.hex_at(ship_q, ship_r)
    log!("Campaign begun. Good luck, Captain #{character.name}.", entry_type: "milestone")
  end

  def assign_planet_sprites!
    sprites = MapLoader.hexes
      .select { |h| h["icon"].in?(PLANET_ICON_TYPES) }
      .each_with_object({}) { |hex, hash| hash["#{hex['q']},#{hex['r']}"] = rand(PLANET_COUNT) }
    update!(planet_sprites: sprites)
  end

  def planet_sprite_for(q, r)
    planet_sprites["#{q},#{r}"] || (q * 7 + r * 11).abs % PLANET_COUNT
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
