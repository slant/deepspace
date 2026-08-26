# frozen_string_literal: true

class JournalEntriesController < ApplicationController
  before_action :set_campaign

  def create
    body = params[:body].to_s.strip
    if body.present?
      @campaign.log!(body, entry_type: "note")
    end

    respond_to do |format|
      format.json { render json: { ok: body.present? } }
      format.html { redirect_to campaign_path(@campaign) }
    end
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.active.find_by!(public_id: params[:campaign_id])
  end
end
