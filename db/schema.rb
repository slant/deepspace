# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_27_230951) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "campaigns", force: :cascade do |t|
    t.string "cargo_sequence"
    t.bigint "character_id"
    t.datetime "created_at", null: false
    t.json "discovered_sectors", default: [], null: false
    t.integer "draft_step", default: 1, null: false
    t.integer "fuel", default: 10, null: false
    t.string "name"
    t.string "public_id", null: false
    t.json "researched_upgrades", default: {}, null: false
    t.json "resolved_events", default: [], null: false
    t.integer "scrap", default: 0, null: false
    t.integer "ship_q"
    t.integer "ship_r"
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["character_id"], name: "index_campaigns_on_character_id"
    t.index ["public_id"], name: "index_campaigns_on_public_id", unique: true
    t.index ["user_id"], name: "index_campaigns_on_user_id"
  end

  create_table "characters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "locked_at"
    t.string "name"
    t.string "ship_name"
    t.integer "ship_type"
    t.datetime "updated_at", null: false
  end

  create_table "journal_entries", force: :cascade do |t|
    t.text "body"
    t.bigint "campaign_id", null: false
    t.datetime "created_at", null: false
    t.string "entry_type"
    t.json "metadata"
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_journal_entries_on_campaign_id"
  end

  create_table "officers", force: :cascade do |t|
    t.string "attribute_a"
    t.string "attribute_b"
    t.bigint "character_id", null: false
    t.datetime "created_at", null: false
    t.string "name", default: "", null: false
    t.integer "position", null: false
    t.string "specialty"
    t.integer "title", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["character_id", "position"], name: "index_officers_on_character_id_and_position", unique: true
    t.index ["character_id"], name: "index_officers_on_character_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "avatar_url"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "name"
    t.string "provider"
    t.datetime "remember_created_at"
    t.string "uid"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true
  end

  add_foreign_key "campaigns", "characters"
  add_foreign_key "campaigns", "users"
  add_foreign_key "journal_entries", "campaigns"
  add_foreign_key "officers", "characters"
end
