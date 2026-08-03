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

ActiveRecord::Schema[8.1].define(version: 2026_08_03_125253) do
  create_table "empires", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "crystal"
    t.integer "energy"
    t.integer "galaxy_id", null: false
    t.integer "home_sector_id"
    t.integer "metal"
    t.integer "player_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["galaxy_id"], name: "index_empires_on_galaxy_id"
    t.index ["player_id"], name: "index_empires_on_player_id"
  end

  create_table "fleets", force: :cascade do |t|
    t.integer "arrival_tick"
    t.datetime "created_at", null: false
    t.integer "empire_id", null: false
    t.integer "galaxy_id", null: false
    t.integer "origin_sector_id"
    t.json "ships"
    t.string "status"
    t.integer "target_sector_id"
    t.datetime "updated_at", null: false
    t.index ["empire_id"], name: "index_fleets_on_empire_id"
    t.index ["galaxy_id"], name: "index_fleets_on_galaxy_id"
  end

  create_table "galaxies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "current_tick"
    t.integer "height"
    t.string "name"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "width"
  end

  create_table "npc_factions", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "galaxy_id", null: false
    t.string "name"
    t.integer "strength_level"
    t.integer "tech_level"
    t.datetime "updated_at", null: false
    t.index ["galaxy_id"], name: "index_npc_factions_on_galaxy_id"
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "sectors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "crystal_rate"
    t.integer "defense_strength"
    t.integer "empire_id"
    t.integer "energy_rate"
    t.integer "galaxy_id", null: false
    t.string "kind"
    t.integer "metal_rate"
    t.string "name"
    t.integer "npc_faction_id"
    t.datetime "updated_at", null: false
    t.integer "x"
    t.integer "y"
    t.index ["empire_id"], name: "index_sectors_on_empire_id"
    t.index ["galaxy_id"], name: "index_sectors_on_galaxy_id"
    t.index ["npc_faction_id"], name: "index_sectors_on_npc_faction_id"
  end

  create_table "ship_types", force: :cascade do |t|
    t.integer "attack"
    t.datetime "created_at", null: false
    t.integer "crystal_cost"
    t.integer "defense"
    t.integer "energy_cost"
    t.integer "metal_cost"
    t.string "name"
    t.string "role"
    t.integer "speed"
    t.datetime "updated_at", null: false
  end

  add_foreign_key "empires", "galaxies"
  add_foreign_key "empires", "players"
  add_foreign_key "fleets", "empires"
  add_foreign_key "fleets", "galaxies"
  add_foreign_key "npc_factions", "galaxies"
  add_foreign_key "sectors", "empires"
  add_foreign_key "sectors", "galaxies"
  add_foreign_key "sectors", "npc_factions"
end
