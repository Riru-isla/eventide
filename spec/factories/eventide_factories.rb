FactoryBot.define do
  factory :player do
    sequence(:name) { |n| "Player #{n}" }
  end

  factory :galaxy do
    sequence(:name) { |n| "Galaxy #{n}" }
    width { 15 }
    height { 15 }
    current_tick { 0 }
    status { "active" }
  end

  factory :npc_faction do
    galaxy
    sequence(:name) { |n| "Faction #{n}" }
    color { "#ef4444" }
    strength_level { 1 }
    tech_level { 1 }
  end

  factory :empire do
    player
    galaxy
    role { "foundry" }
    metal { 500 }
    crystal { 500 }
    energy { 500 }
  end

  factory :sector do
    galaxy
    sequence(:x) { |n| n % 15 }
    sequence(:y) { |n| n / 15 }
    kind { "empty" }
    sequence(:name) { |n| "Sector #{n}" }
    metal_rate { 10 }
    crystal_rate { 10 }
    energy_rate { 10 }
    defense_strength { 0 }
  end

  factory :fleet do
    empire
    galaxy { empire.galaxy }
    origin_sector factory: :sector
    status { "orbiting" }
    ships { { "Fighter" => 10 } }
  end

  factory :ship_type do
    sequence(:name) { |n| "Ship Type #{n}" }
    role { nil }
    metal_cost { 10 }
    crystal_cost { 10 }
    energy_cost { 10 }
    attack { 10 }
    defense { 10 }
    speed { 2 }
  end
end
