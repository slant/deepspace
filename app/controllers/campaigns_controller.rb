# frozen_string_literal: true

class CampaignsController < ApplicationController
  before_action :set_campaign, only: %i[show update destroy]

  def index
    @campaigns = current_user.campaigns.includes(:character).order(updated_at: :desc)
  end

  def show
    redirect_to edit_campaign_character_path(@campaign) if @campaign.draft?

    respond_to do |format|
      format.html
      format.json { render json: { campaign: campaign_json(@campaign) } }
    end
  end

  def new
    @campaign = current_user.campaigns.create!(status: :draft, name: "New Campaign")
    redirect_to edit_campaign_character_path(@campaign, step: 1)
  end

  def update
    if @campaign.update(campaign_params)
      respond_to do |format|
        format.json { render json: { ok: true, campaign: campaign_json(@campaign) } }
        format.html { redirect_to campaign_path(@campaign) }
      end
    else
      render json: { ok: false, errors: @campaign.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    @campaign.destroy
    redirect_to campaigns_path, notice: "Campaign deleted."
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(
      :fuel, :scrap, :cargo_sequence, :ship_q, :ship_r,
      discovered_sectors: [], resolved_events: [],
      researched_upgrades: {}
    )
  end

  def campaign_json(campaign)
    {
      id: campaign.id,
      fuel: campaign.fuel,
      scrap: campaign.scrap,
      ship_q: campaign.ship_q,
      ship_r: campaign.ship_r,
      cargo_sequence: campaign.cargo_sequence,
      status: campaign.status
    }
  end
end
