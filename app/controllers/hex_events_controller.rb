# frozen_string_literal: true

class HexEventsController < ApplicationController
  before_action :set_campaign

  def show
    hex = MapLoader.hex_at(params[:q].to_i, params[:r].to_i)
    return head :not_found unless hex

    if !@campaign.at_hex?(hex["q"], hex["r"]) && @campaign.adjacent_to?(hex["q"], hex["r"]) && @campaign.fuel <= 0
      adrift = EventCatalog.for_event("21-A")
      return render json: adrift.merge(
        choices: annotate_choices(adrift[:choices]),
        hex: hex.slice("q", "r", "label", "icon", "note", "sector"),
        campaign: { ship_q: @campaign.ship_q, ship_r: @campaign.ship_r, fuel: @campaign.fuel, scrap: @campaign.scrap, resolved: false }
      )
    end

    unless @campaign.at_hex?(hex["q"], hex["r"]) || @campaign.can_move_to?(hex["q"], hex["r"])
      return render json: { error: "Cannot interact with this hex" }, status: :forbidden
    end

    if @campaign.can_move_to?(hex["q"], hex["r"])
      @campaign.move_to!(hex["q"], hex["r"])
      region = hex["sector"]
      @campaign.discover_sector!(region) if region.present?
    end

    event = EventCatalog.for_hex(hex, campaign: @campaign)
    event = event.merge(choices: annotate_choices(event[:choices]))
    render json: event.merge(
      hex: hex.slice("q", "r", "label", "icon", "note", "sector"),
      campaign: {
        ship_q: @campaign.ship_q,
        ship_r: @campaign.ship_r,
        fuel: @campaign.fuel,
        scrap: @campaign.scrap,
        resolved: @campaign.resolved_events.include?(hex["label"])
      }
    )
  end

  def update
    hex = MapLoader.hex_at(params[:q].to_i, params[:r].to_i)
    return head :not_found unless hex

    scrap_delta = params[:scrap_delta].to_i
    fuel_delta  = params[:fuel_delta].to_i

    case params[:action_type]
    when "goto"
      goto_target = params[:goto_target].to_s
      next_event = EventCatalog.for_event(goto_target)
      return head :not_found unless next_event

      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
      apply_item_and_sequence_effects!
      from_label = params[:current_event_label].presence || hex["label"]
      @campaign.log!("#{from_label} → #{goto_target}", entry_type: "event")

      next_event = next_event.merge(choices: annotate_choices(next_event[:choices]))
      return render json: {
        ok: true,
        next_event: next_event.merge(hex: hex.slice("q", "r", "label", "icon", "note", "sector")),
        campaign: campaign_state
      }

    when "game_over"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
      apply_item_and_sequence_effects!
      @campaign.update!(status: :failed)
      @campaign.log!("Mission failed.", entry_type: "milestone")

      return render json: {
        ok: true,
        game_over: true,
        title: params[:title].presence || "Mission Failed",
        body: params[:body].presence || "Your journey ends here.",
        campaign: campaign_state
      }

    when "resolve"
      @campaign.resolve_event!(hex["label"]) if hex["label"].present?

    when "complete"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
      apply_item_and_sequence_effects!
      @campaign.update!(status: :completed)
      @campaign.log!("Reached home. Mission complete.", entry_type: "milestone")

    when "orbit"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
      apply_item_and_sequence_effects!
    end

    render json: { ok: true, campaign: campaign_state.merge(resolved_events: @campaign.resolved_events) }
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.active.find_by!(public_id: params[:campaign_id])
  end

  def campaign_state
    {
      scrap: @campaign.scrap,
      fuel: @campaign.fuel,
      status: @campaign.status,
      items: @campaign.items,
      cargo_marks: @campaign.cargo_marks
    }
  end

  # Applies item/cargo-sequence side effects from choice metadata. Mirrors
  # apply_resource_delta! — the client echoes back the metadata from the
  # choice it selected (see event_modal_controller.js), never re-derived
  # from label text.
  def apply_item_and_sequence_effects!
    Array(params[:gain_items]).each { |name| @campaign.gain_item!(name) }
    @campaign.gain_item!(params[:gain_item]) if params[:gain_item].present?

    unless params[:lose_item_unless].present? && requirement_met?(params[:lose_item_unless])
      Array(params[:lose_items]).each { |name| @campaign.lose_item!(name) }
      @campaign.lose_item!(params[:lose_item]) if params[:lose_item].present?
    end

    @campaign.mark_sequence!(params[:mark_sequence], params[:mark_type]) if params[:mark_sequence].present? && params[:mark_type].present?

    if params[:gain_random_officer_attribute].present?
      count = params[:gain_random_officer_attribute_count].presence&.to_i || 1
      @campaign.add_random_officer_attribute!(params[:gain_random_officer_attribute], count: count)
    end
    @campaign.add_all_officers_attribute!(params[:gain_all_officers_attribute]) if params[:gain_all_officers_attribute].present?
    @campaign.kill_random_officer! if ActiveModel::Type::Boolean.new.cast(params[:kill_random_officer])
    @campaign.roll_fatigue_check! if ActiveModel::Type::Boolean.new.cast(params[:crew_dice_fatigue_check])
    @campaign.apply_fatigue_threshold! if ActiveModel::Type::Boolean.new.cast(params[:apply_fatigue_threshold])
  end

  def requirement_met?(requires_param)
    requires = requires_param.is_a?(String) ? JSON.parse(requires_param) : requires_param.to_unsafe_h
    ChoiceRequirement.satisfied?(requires, campaign: @campaign)
  rescue JSON::ParserError
    false
  end

  def annotate_choices(choices)
    (choices || []).map do |choice|
      requires = choice.dig("metadata", "requires")
      choice.merge("locked" => !ChoiceRequirement.satisfied?(requires, campaign: @campaign))
    end
  end
end
