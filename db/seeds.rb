# Seed ship types available to all empires.
ship_types = [
  { name: "Fighter", role: nil, metal_cost: 10, crystal_cost: 5, energy_cost: 5, attack: 5, defense: 3, speed: 3 },
  { name: "Cruiser", role: nil, metal_cost: 50, crystal_cost: 30, energy_cost: 30, attack: 20, defense: 25, speed: 2 },
  { name: "Harvester", role: "cultivator", metal_cost: 40, crystal_cost: 20, energy_cost: 20, attack: 2, defense: 10, speed: 2 },
  { name: "Dreadnought", role: "foundry", metal_cost: 100, crystal_cost: 60, energy_cost: 60, attack: 50, defense: 60, speed: 1 },
  { name: "Carrier", role: "warden", metal_cost: 80, crystal_cost: 50, energy_cost: 50, attack: 15, defense: 40, speed: 2 }
]

ship_types.each do |attrs|
  ShipType.find_or_create_by!(name: attrs[:name]) do |st|
    st.assign_attributes(attrs)
  end
end

# Create a demo galaxy if none exists.
if Galaxy.none?
  galaxy = GalaxyGenerator.new(
    name: "Eventide Alpha",
    width: 15,
    height: 15,
    player_configs: [
      { name: "Ada", role: "cultivator" },
      { name: "Ben", role: "foundry" },
      { name: "Cara", role: "warden" }
    ]
  ).generate

  puts "Created galaxy '#{galaxy.name}' with #{galaxy.sectors.count} sectors and #{galaxy.empires.count} empires."
else
  puts "Galaxy already exists; skipping demo generation."
end
