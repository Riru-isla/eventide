FactoryBot.define do
  factory :player do
    user
    galaxy
    sequence(:name) { |n| "Player #{n}" }
  end

  factory :galaxy do
    sequence(:name) { |n| "Galaxy #{n}" }
    width { 15 }
    height { 15 }
    current_tick { 0 }
    status { "active" }
    core_x { 12 }
    core_y { 7 }
  end

  factory :sector do
    galaxy
    sequence(:name) { |n| "Sector #{n}" }
    seed_x { 5 }
    seed_y { 5 }
    weight { 1.0 }
    kind { "standard" }
    power_level { 1 }
  end

  factory :npc_faction do
    galaxy
    sequence(:name) { |n| "Faction #{n}" }
    color { "#ef4444" }
    strength_level { 1 }
    tech_level { 1 }
    power_level { 1 }
  end

  factory :empire do
    player
    galaxy
    role { "foundry" }
    metal { 500 }
    crystal { 500 }
    energy { 500 }
  end

  factory :system do
    galaxy
    sequence(:x) { |n| n % 15 }
    sequence(:y) { |n| n / 15 }
    kind { "empty" }
    sequence(:name) { |n| "System #{n}" }
    metal_rate { 10 }
    crystal_rate { 10 }
    energy_rate { 10 }
    defense_strength { 0 }
  end

  factory :fleet do
    empire
    galaxy { empire.galaxy }
    origin_system factory: :system
    status { "orbiting" }
    ships { { "light_fighter" => 10 } }
  end
end
