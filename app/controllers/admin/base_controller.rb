# Admin screens are about the server rather than about a commander, so they must not demand
# an empire: an administrator may hold none at all, in any galaxy.
class Admin::BaseController < ApplicationController
  skip_before_action :require_empire
  before_action :require_admin
end
