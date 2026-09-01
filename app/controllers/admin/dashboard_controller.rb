class Admin::DashboardController < Admin::BaseController
  def show
    @galaxies = Galaxy.order(created_at: :desc)
    @commanders = Player.group(:galaxy_id).count
    @factions = NpcFaction.group(:galaxy_id).count
    # How the AI is actually doing, which is the whole reason an admin looks at this page.
    @roused = NpcFaction.roused.group(:galaxy_id).count
    @banked = Empire.artificial.group(:galaxy_id).sum(:metal)
    @building = FactionProject.joins(:npc_faction).group("npc_factions.galaxy_id").count
    @accounts = User.includes(empires: [ :galaxy, :player ]).order(:username)
  end
end
