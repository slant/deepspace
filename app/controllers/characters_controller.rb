# frozen_string_literal: true

class CharactersController < ApplicationController
  before_action :set_campaign

  def edit
    @step = (params[:step] || @campaign.draft_step).to_i.clamp(1, 2)
    build_character_wizard
  end

  def update
    @step = params[:step].to_i

    if @step == 1
      save_step_one
    elsif @step == 2
      save_step_two
    else
      redirect_to edit_campaign_character_path(@campaign, step: 1)
    end
  end

  private

  def set_campaign
    @campaign = current_user.campaigns.find(params[:campaign_id])
    redirect_to campaign_path(@campaign) unless @campaign.draft?
  end

  def build_character_wizard
    @character = @campaign.character || @campaign.build_character
    4.times do |i|
      @character.officers.find { |o| o.position == i } ||
        @character.officers.build(position: i, title: Officer::TITLES.keys[i])
    end
  end

  def save_step_one
    @character = @campaign.character || @campaign.build_character
    @character.assign_attributes(character_step_one_params)
    if @character.save
      @campaign.update!(character: @character, draft_step: 2)
      redirect_to edit_campaign_character_path(@campaign, step: 2)
    else
      @step = 1
      render :edit, status: :unprocessable_entity
    end
  end

  def save_step_two
    @character = @campaign.character || @campaign.build_character
    if @character.update(character_step_two_params)
      @character.lock!
      @campaign.update!(character: @character, draft_step: 2)
      @campaign.activate!
      redirect_to campaign_path(@campaign), notice: "Campaign launched. Good luck, Captain."
    else
      @step = 2
      render :edit, status: :unprocessable_entity
    end
  end

  def character_step_one_params
    params.require(:character).permit(:name, :ship_name, :ship_type)
  end

  def character_step_two_params
    params.require(:character).permit(
      officers_attributes: %i[id name title specialty attribute_a attribute_b position]
    )
  end
end
