# frozen_string_literal: true

class Campaign < ApplicationRecord
  DEFAULT_CARGO = "000-2-134711-182947-76123199-322521-8431364-L-M-Z".freeze
  START_HEX = { q: 2, r: 7 }.freeze
  PLANET_COUNT = 30
  PLANET_ICON_TYPES = %w[circle beacon_store].freeze

  # R&D upgrade tracks (character sheet, PDF p.6). Box labels are the exact
  # crew-die result(s) required to fill that box, pre-abbreviated for display;
  # a box with more than one requirement (e.g. Bio-Manipulator's 3rd box) is
  # paid all at once, per the user — modeled as a single box, not two. Boxes
  # are self-reported (tap to mark) rather than rolled by the app — see
  # CLAUDE.md "Crew Dice"/dice-roll scope: R&D dice are rolled physically
  # during combat/Duty Phase, the app only tracks progress the player already
  # made. scrap_cost (if any) is paid once, when the last box is marked.
  RND_TRACKS = {
    "engine_repair" => {
      name: "Engine Repair",
      boxes: [ "1 ENG", "1 ENG", "2 ENG", "1 ENG", "1 ENG", "2 ENG", "1 ENG", "1 ENG", "3 ENG" ],
      scrap_cost: 10
    },
    "promotion" => {
      name: "Promotion",
      boxes: [ "1 CMD", "1 CMD", "2 CMD" ],
      scrap_cost: 0
    },
    "kinetic_recycler" => {
      name: "Kinetic Recycler",
      boxes: [ "2 ENG", "1 ENG", "1 ENG" ],
      scrap_cost: 0
    },
    "lr_scanners" => {
      name: "LR Scanners",
      boxes: [ "1 ENG", "1 CMD", "2 CMD" ],
      scrap_cost: 0
    },
    "bio_manipulator" => {
      name: "Bio-Manipulator",
      boxes: [ "1 MED", "1 MED", "1 MED + 1 ENG" ],
      scrap_cost: 0
    },
    "cloaking_device" => {
      name: "Cloaking Device",
      boxes: [ "1 ANY", "1 ENG", "2 ENG", "1 ENG", "1 SCI", "2 SCI" ],
      scrap_cost: 25
    }
  }.freeze

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

  def journey_summary
    {
      moves: journal_entries.where(entry_type: "movement").count,
      sectors_discovered: discovered_sectors.size,
      items_collected: items.count { |i| !i["lost"] },
      items_lost: items.count { |i| i["lost"] },
      sequences_marked: cargo_marks.size,
      officers_lost: character.officers.count(&:dead?),
      final_position: current_hex_label
    }
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

  # 2 with Engine Repair researched, 1 otherwise. Still costs a flat 1 fuel
  # per move regardless of distance covered — Engine Repair extends reach,
  # not fuel efficiency. See docs/reference/deep-space-d6-mechanics.md.
  def move_range
    upgrade_researched?("engine_repair") ? 2 : 1
  end

  def within_move_range?(q, r)
    HexGrid.distance(ship_q, ship_r, q, r).between?(1, move_range)
  end

  def can_move_to?(q, r)
    return false unless active?
    return false unless within_move_range?(q, r)
    return false if fuel <= 0

    true
  end

  def move_to!(q, r)
    raise ArgumentError, "Invalid move" unless can_move_to?(q, r)

    transaction do
      update!(ship_q: q, ship_r: r, previous_ship_q: ship_q, previous_ship_r: ship_r, fuel: fuel - 1)
      log!("Moved to #{MapLoader.hex_at(q, r)&.dig('label') || "#{q},#{r}"}", entry_type: "movement")
    end
  end

  # Jump Drive (requires Engine Repair, costs 1 fuel): return to the
  # immediately-previous hex position — not a special map location, just an
  # undo of the last move. Bypasses EventCatalog entirely (no Open Space
  # encounter triggers on return), per docs/reference/deep-space-d6-mechanics.md.
  # The combat-escape use of Jump Drive happens entirely on the player's
  # physical copy of the game and has nothing for this app to track.
  def can_jump_drive?
    return false unless active?
    return false unless upgrade_researched?("engine_repair")
    return false if fuel <= 0

    previous_ship_q.present? && previous_ship_r.present?
  end

  def jump_drive!
    raise "Jump Drive unavailable" unless can_jump_drive?

    transaction do
      target_q, target_r = previous_ship_q, previous_ship_r
      update!(ship_q: target_q, ship_r: target_r, previous_ship_q: ship_q, previous_ship_r: ship_r, fuel: fuel - 1)
      log!("Jump Drive — returned to #{MapLoader.hex_at(target_q, target_r)&.dig('label') || "#{target_q},#{target_r}"}", entry_type: "movement")
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

  # --- Officer mutations ---
  # Permanent in-play officer changes from events. "Random" selections are
  # made here (not left to the client) since Campaign is the single source
  # of truth for what already happened this playthrough.

  def add_random_officer_attribute!(name, count: 1)
    living = character.officers.reload.reject(&:dead?)
    return if living.empty?

    chosen = living.sample(count)
    chosen.each { |o| o.add_attribute!(name) }
    log!("#{chosen.map(&:name).join(', ')} gained #{name.upcase}", entry_type: "officer")
  end

  def add_all_officers_attribute!(name)
    character.officers.reload.each { |o| o.add_attribute!(name) }
    log!("All officers gained #{name.upcase}", entry_type: "officer")
  end

  def kill_random_officer!
    living = character.officers.reload.reject(&:dead?)
    return if living.empty?

    officer = living.sample
    officer.kill!
    log!("Officer #{officer.name} was lost", entry_type: "officer")
  end

  # Rolls 2 crew dice per living officer; any officer whose pair includes a
  # Threat Detected result gains an X mark (event pattern: 39-B, 42-A, 51-B,
  # 61-B, 70-A, 72-A). Marks accumulate silently — they're only checked
  # against the fatigue threshold when a specific event calls for it (43-A).
  def roll_fatigue_check!(dice_per_officer: 2)
    marked = []
    character.officers.reload.reject(&:dead?).each do |officer|
      roll = CrewDice.roll(dice_per_officer)
      next unless roll.include?("threat_detected")

      officer.add_fatigue_mark!
      marked << officer.name
    end

    text = marked.any? ? "#{marked.join(', ')} rattled by a Threat Detected result (X mark)." : "Crew dice rolled clean — no X marks."
    log!(text.chomp("."), entry_type: "officer")
    text
  end

  # Applies the fatigue threshold check (event 43-A): any officer at or past
  # their threshold is crossed out — "may no longer be used." Reuses the
  # existing dead/kill! exclusion machinery rather than a parallel state,
  # since the gameplay effect (excluded from ChoiceRequirement, from other
  # officer-mutation sampling, etc.) is identical to death.
  def apply_fatigue_threshold!
    fatigued = character.officers.reload.reject(&:dead?).select(&:fatigued?)
    fatigued.each(&:kill!)
    return if fatigued.empty?

    log!("#{fatigued.map(&:name).join(', ')} fatigued past their limit — crossed out", entry_type: "officer")
  end

  # --- Research & Development ---
  # researched_upgrades: { track_id => { "marked_boxes" => [Boolean], "researched" => Boolean } }

  def upgrade_marked_boxes(track)
    stored = researched_upgrades.dig(track, "marked_boxes")
    stored.presence || Array.new(RND_TRACKS.fetch(track)[:boxes].size, false)
  end

  def upgrade_researched?(track)
    researched_upgrades.dig(track, "researched") == true
  end

  def toggle_upgrade_box!(track, index)
    return if upgrade_researched?(track)

    boxes = RND_TRACKS.fetch(track)[:boxes]
    return unless index.between?(0, boxes.size - 1)

    marked = upgrade_marked_boxes(track).dup
    marked[index] = !marked[index]
    update!(researched_upgrades: researched_upgrades.merge(
      track => (researched_upgrades[track] || {}).merge("marked_boxes" => marked)
    ))

    complete_upgrade!(track) if marked.all? && RND_TRACKS.fetch(track)[:scrap_cost].zero?
  end

  # Deducts the track's scrap cost (if any) and marks it permanently
  # researched. Called automatically when a free track's last box is marked;
  # called explicitly (via the Upgrades panel's "Complete" button) for a
  # track with a scrap cost, since that's a resource spend the player should
  # confirm rather than have triggered as a side effect of a tap.
  def complete_upgrade!(track)
    return false if upgrade_researched?(track)
    return false unless upgrade_marked_boxes(track).all?

    cost = RND_TRACKS.fetch(track)[:scrap_cost]
    return false if scrap < cost

    transaction do
      update!(scrap: scrap - cost) if cost.positive?
      update!(researched_upgrades: researched_upgrades.merge(
        track => (researched_upgrades[track] || {}).merge("researched" => true)
      ))
    end
    log!("Research complete: #{RND_TRACKS.fetch(track)[:name]}", entry_type: "milestone")
    true
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
