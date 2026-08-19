namespace :galaxy do
  desc "Generate a throwaway galaxy, print its sectors and write an SVG to tmp/. Persists nothing."
  task :preview, [ :size, :players ] => :environment do |_task, args|
    size = args[:size] || "small"
    players = (args[:players] || 4).to_i
    path = Rails.root.join("tmp", "galaxy-preview-#{size}.svg")

    ActiveRecord::Base.transaction do
      started = Time.current
      galaxy = GalaxyGenerator.new(
        name: "Preview",
        size: size,
        player_configs: Array.new(players) { |i| { name: "P#{i + 1}", role: "foundry", username: "preview-#{i}" } }
      ).generate
      elapsed = (Time.current - started).round(2)

      preview = GalaxyPreview.new(galaxy)
      File.write(path, preview.to_svg)

      puts format("%-24s %-9s %-4s %-7s %-8s %-7s %s", "SECTOR", "KIND", "LVL", "WEIGHT", "SYSTEMS", "HELD", "SEED")
      preview.summary.each do |row|
        puts format("%-24s %-9s %-4d %-7.2f %-8d %-7d %s",
                    row[:name], row[:kind], row[:power_level], row[:weight],
                    row[:systems], row[:garrisoned], row[:seed])
      end

      puts
      puts "PLAYER   FIRST FIGHT   FIRST CAPITAL"
      preview.frontier.each do |row|
        puts format("%-8s %5d ticks   %5d ticks", row[:player], row[:garrison_ticks], row[:capital_ticks])
      end

      puts
      puts "#{galaxy.systems.count} systems in #{elapsed}s · core #{galaxy.core_x},#{galaxy.core_y}"
      puts "wrote #{path}"

      # Nothing is kept: this is for looking at generation, not for creating a session.
      raise ActiveRecord::Rollback
    end
  end
end
