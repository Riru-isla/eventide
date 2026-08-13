# Ship hulls live in the ShipType catalogue (app/models/ship_type.rb), not the database.

# Create a demo galaxy if none exists.
if Galaxy.none?
  galaxy = GalaxyGenerator.new(
    name: "Eventide Alpha",
    size: ENV.fetch("GALAXY_SIZE", "small"),
    player_configs: [
      { name: "Ada", role: "cultivator" },
      { name: "Ben", role: "foundry" },
      { name: "Cara", role: "warden" }
    ]
  ).generate

  puts "Created galaxy '#{galaxy.name}' (#{galaxy.size}, #{galaxy.width}x#{galaxy.height}) " \
       "with #{galaxy.sectors.count} sectors and #{galaxy.empires.count} empires."

  galaxy.npc_factions.by_tier.each do |faction|
    puts "  tier #{faction.tier} #{faction.name}: #{faction.sectors.count} sectors, " \
         "capital #{faction.capital_sector&.coordinate}, #{faction.aggression}"
  end
else
  puts "Galaxy already exists; skipping demo generation."
end
