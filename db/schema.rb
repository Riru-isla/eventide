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

ActiveRecord::Schema[8.1].define(version: 2026_08_19_170000) do
  create_table "build_orders", force: :cascade do |t|
    t.integer "completes_at_tick"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.integer "planet_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "started_at_tick"
    t.integer "target_level", null: false
    t.integer "ticks_required", null: false
    t.datetime "updated_at", null: false
    t.index ["completes_at_tick"], name: "index_build_orders_on_completes_at_tick"
    t.index ["planet_id", "position"], name: "index_build_orders_on_planet_id_and_position"
    t.index ["planet_id"], name: "index_build_orders_on_planet_id"
  end

  create_table "empire_technologies", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "empire_id", null: false
    t.string "kind", null: false
    t.integer "level", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["empire_id", "kind"], name: "index_empire_technologies_on_empire_id_and_kind", unique: true
    t.index ["empire_id"], name: "index_empire_technologies_on_empire_id"
  end

  create_table "empires", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "crew", default: 0, null: false
    t.integer "crystal"
    t.integer "energy"
    t.integer "galaxy_id", null: false
    t.integer "home_system_id"
    t.integer "metal"
    t.integer "player_id", null: false
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["galaxy_id"], name: "index_empires_on_galaxy_id"
    t.index ["player_id"], name: "index_empires_on_player_id"
  end

  create_table "fleets", force: :cascade do |t|
    t.integer "arrival_tick"
    t.json "cargo", default: {}
    t.datetime "created_at", null: false
    t.integer "empire_id", null: false
    t.integer "galaxy_id", null: false
    t.string "mission", default: "attack", null: false
    t.integer "origin_system_id"
    t.json "ships"
    t.string "status"
    t.integer "target_system_id"
    t.datetime "updated_at", null: false
    t.index ["empire_id"], name: "index_fleets_on_empire_id"
    t.index ["galaxy_id"], name: "index_fleets_on_galaxy_id"
    t.index ["status"], name: "index_fleets_on_status"
  end

  create_table "galaxies", force: :cascade do |t|
    t.string "awareness_level", default: "standard", null: false
    t.integer "core_x", null: false
    t.integer "core_y", null: false
    t.datetime "created_at", null: false
    t.integer "current_tick"
    t.integer "faction_count", default: 4, null: false
    t.integer "height"
    t.string "name"
    t.string "size", default: "small", null: false
    t.string "status"
    t.integer "team_count", default: 1, null: false
    t.string "threat_level", default: "standard", null: false
    t.datetime "updated_at", null: false
    t.string "victory_condition", default: "reach_the_core", null: false
    t.integer "width"
  end

  create_table "npc_factions", force: :cascade do |t|
    t.string "aggression", default: "unaware", null: false
    t.integer "awareness", default: 50, null: false
    t.integer "capital_system_id"
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "fallen_at_tick"
    t.integer "galaxy_id", null: false
    t.string "name"
    t.integer "power_level", default: 1, null: false
    t.integer "sector_id"
    t.integer "strength_level"
    t.integer "tech_level"
    t.datetime "updated_at", null: false
    t.index ["capital_system_id"], name: "index_npc_factions_on_capital_system_id"
    t.index ["galaxy_id", "power_level"], name: "index_npc_factions_on_galaxy_id_and_power_level"
    t.index ["galaxy_id"], name: "index_npc_factions_on_galaxy_id"
    t.index ["sector_id"], name: "index_npc_factions_on_sector_id"
  end

  create_table "planet_structures", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.integer "level", default: 0, null: false
    t.integer "planet_id", null: false
    t.datetime "updated_at", null: false
    t.index ["planet_id", "kind"], name: "index_planet_structures_on_planet_id_and_kind", unique: true
    t.index ["planet_id"], name: "index_planet_structures_on_planet_id"
  end

  create_table "planets", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "empire_id", null: false
    t.string "name", null: false
    t.integer "system_id", null: false
    t.datetime "updated_at", null: false
    t.index ["empire_id"], name: "index_planets_on_empire_id"
    t.index ["system_id"], name: "index_planets_on_system_id", unique: true
  end

  create_table "players", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "galaxy_id", null: false
    t.string "name"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["galaxy_id"], name: "index_players_on_galaxy_id"
    t.index ["user_id", "galaxy_id"], name: "index_players_on_user_id_and_galaxy_id", unique: true
    t.index ["user_id"], name: "index_players_on_user_id"
  end

  create_table "research_orders", force: :cascade do |t|
    t.integer "completes_at_tick"
    t.datetime "created_at", null: false
    t.integer "empire_id", null: false
    t.string "kind", null: false
    t.integer "started_at_tick"
    t.integer "target_level", null: false
    t.integer "ticks_required", null: false
    t.datetime "updated_at", null: false
    t.index ["completes_at_tick"], name: "index_research_orders_on_completes_at_tick"
    t.index ["empire_id"], name: "index_research_orders_on_empire_id"
  end

  create_table "sectors", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "galaxy_id", null: false
    t.string "kind", default: "standard", null: false
    t.string "name", null: false
    t.integer "power_level", default: 1, null: false
    t.integer "seed_x", null: false
    t.integer "seed_y", null: false
    t.datetime "updated_at", null: false
    t.float "weight", default: 1.0, null: false
    t.index ["galaxy_id"], name: "index_sectors_on_galaxy_id"
  end

  create_table "ship_orders", force: :cascade do |t|
    t.integer "completes_at_tick"
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.integer "planet_id", null: false
    t.integer "position", default: 0, null: false
    t.integer "quantity", null: false
    t.integer "started_at_tick"
    t.integer "ticks_required", null: false
    t.datetime "updated_at", null: false
    t.index ["completes_at_tick"], name: "index_ship_orders_on_completes_at_tick"
    t.index ["planet_id", "position"], name: "index_ship_orders_on_planet_id_and_position"
    t.index ["planet_id"], name: "index_ship_orders_on_planet_id"
  end

  create_table "systems", force: :cascade do |t|
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
    t.integer "sector_id"
    t.datetime "updated_at", null: false
    t.integer "x"
    t.integer "y"
    t.index ["empire_id"], name: "index_systems_on_empire_id"
    t.index ["galaxy_id"], name: "index_systems_on_galaxy_id"
    t.index ["npc_faction_id"], name: "index_systems_on_npc_faction_id"
    t.index ["sector_id"], name: "index_systems_on_sector_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.datetime "updated_at", null: false
    t.string "username", default: "", null: false
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "build_orders", "planets"
  add_foreign_key "empire_technologies", "empires"
  add_foreign_key "empires", "galaxies"
  add_foreign_key "empires", "players"
  add_foreign_key "fleets", "empires"
  add_foreign_key "fleets", "galaxies"
  add_foreign_key "npc_factions", "galaxies"
  add_foreign_key "npc_factions", "sectors"
  add_foreign_key "npc_factions", "systems", column: "capital_system_id"
  add_foreign_key "planet_structures", "planets"
  add_foreign_key "planets", "empires"
  add_foreign_key "planets", "systems"
  add_foreign_key "players", "galaxies"
  add_foreign_key "players", "users"
  add_foreign_key "research_orders", "empires"
  add_foreign_key "sectors", "galaxies"
  add_foreign_key "ship_orders", "planets"
  add_foreign_key "systems", "empires"
  add_foreign_key "systems", "galaxies"
  add_foreign_key "systems", "npc_factions"
  add_foreign_key "systems", "sectors"
end
