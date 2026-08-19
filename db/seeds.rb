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
       "with #{galaxy.systems.count} systems and #{galaxy.empires.count} empires."

  galaxy.npc_factions.by_power.each do |faction|
    puts "  L#{faction.power_level} #{faction.name} (#{faction.sector.name}): " \
         "#{faction.systems.count} systems, capital #{faction.capital_system&.coordinate}, #{faction.aggression}"
  end
else
  puts "Galaxy already exists; skipping demo generation."
end
