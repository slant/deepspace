# frozen_string_literal: true

class HexEventsController < ApplicationController
  before_action :set_campaign

  def show
    hex = MapLoader.hex_at(params[:q].to_i, params[:r].to_i)
    return head :not_found unless hex

    unless @campaign.at_hex?(hex["q"], hex["r"]) || @campaign.can_move_to?(hex["q"], hex["r"])
      return render json: { error: "Cannot interact with this hex" }, status: :forbidden
    end

    if @campaign.can_move_to?(hex["q"], hex["r"])
      @campaign.move_to!(hex["q"], hex["r"])
      region = hex["sector"]
      @campaign.discover_sector!(region) if region.present?
    end

    event = EventCatalog.for_hex(hex, campaign: @campaign)
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
      from_label = params[:current_event_label].presence || hex["label"]
      @campaign.log!("#{from_label} → #{goto_target}", entry_type: "event")

      return render json: {
        ok: true,
        next_event: next_event.merge(hex: hex.slice("q", "r", "label", "icon", "note", "sector")),
        campaign: campaign_state
      }

    when "game_over"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
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
      @campaign.update!(status: :completed)
      @campaign.log!("Reached home. Mission complete.", entry_type: "milestone")

    when "orbit"
      @campaign.apply_resource_delta!(scrap_delta: scrap_delta, fuel_delta: fuel_delta)
    end

    render json: { ok: true, campaign: campaign_state.merge(resolved_events: @campaign.resolved_events) }
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.find_by!(public_id: params[:campaign_id])
  end

  def campaign_state
    {
      scrap: @campaign.scrap,
      fuel: @campaign.fuel,
      status: @campaign.status
    }
  end
end
