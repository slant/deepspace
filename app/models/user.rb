# frozen_string_literal: true

class User < ApplicationRecord
  devise :omniauthable, :rememberable, :database_authenticatable

  has_many :campaigns, dependent: :destroy

  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.avatar_url = auth.info.image
      user.password = Devise.friendly_token[0, 20]
    end
  end

  def password_required?
    false
  end
end
