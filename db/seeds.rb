# Ship hulls live in the ShipType catalogue (app/models/ship_type.rb), not the database.

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
