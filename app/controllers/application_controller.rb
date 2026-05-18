# frozen_string_literal: true

class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  before_action :authenticate_user!, unless: :public_page?

  helper_method :current_user

  private

  def public_page?
    controller_name == "pages" && action_name == "home"
  end

  def after_sign_in_path_for(_resource)
    campaigns_path
  end
end
