# frozen_string_literal: true

class UpgradesController < ApplicationController
  before_action :set_campaign
  before_action :set_track

  def toggle_box
    return head :not_found unless @track

    @campaign.toggle_upgrade_box!(@track, params[:box].to_i)
    render json: { ok: true, campaign: campaign_state }
  end

  def complete
    return head :not_found unless @track

    if @campaign.complete_upgrade!(@track)
      render json: { ok: true, campaign: campaign_state }
    else
      render json: { error: "Cannot complete this upgrade yet" }, status: :unprocessable_entity
    end
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.active.find_by!(public_id: params[:campaign_id])
  end

  def set_track
    @track = params[:track] if Campaign::RND_TRACKS.key?(params[:track])
  end

  def campaign_state
    { scrap: @campaign.scrap, researched_upgrades: @campaign.researched_upgrades }
  end
end
