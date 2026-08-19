class Admin::DashboardController < Admin::BaseController
  def show
    @galaxies = Galaxy.order(created_at: :desc)
    @commanders = Player.group(:galaxy_id).count
    @factions = NpcFaction.group(:galaxy_id).count
    @accounts = User.includes(empires: [ :galaxy, :player ]).order(:username)
  end
end
