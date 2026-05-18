# frozen_string_literal: true

class JournalEntry < ApplicationRecord
  belongs_to :campaign
end
