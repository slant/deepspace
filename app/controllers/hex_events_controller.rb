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
      region = hex["region"]
      @campaign.discover_sector!(region) if region.present?
    end

    event = EventCatalog.for_hex(hex, campaign: @campaign)
    render json: event.merge(
      hex: hex.slice("q", "r", "label", "icon", "note", "region"),
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

    case params[:action_type]
    when "resolve"
      @campaign.resolve_event!(hex["label"]) if hex["label"].present?
    when "complete"
      @campaign.update!(status: :completed)
      @campaign.log!("Reached home. Mission complete.", entry_type: "milestone")
    when "orbit"
      # no-op; player ends turn narratively
    end

    render json: { ok: true, campaign: { resolved_events: @campaign.resolved_events, status: @campaign.status } }
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.active.find(params[:campaign_id])
  end
end
