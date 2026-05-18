Rails.application.routes.draw do
  devise_for :users, controllers: {
    omniauth_callbacks: "users/omniauth_callbacks"
  }, skip: %i[registrations passwords sessions]

  delete "users/sign_out", to: "users/sessions#destroy", as: :destroy_user_session

  root "pages#home"

  resources :campaigns, only: %i[index show new update destroy] do
    resource :character, only: %i[edit update]
  end

  get "campaigns/:campaign_id/hex/:q/:r", to: "hex_events#show", as: :campaign_hex_event
  patch "campaigns/:campaign_id/hex/:q/:r", to: "hex_events#update", as: :campaign_hex_event_update

  get "up" => "rails/health#show", as: :rails_health_check
end
