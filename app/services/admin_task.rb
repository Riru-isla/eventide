# The only way an account becomes an administrator. Deliberately outside the game: admins
# run the server rather than play it, so there is no path from being a player to being one.
#
# The rake tasks in lib/tasks/admin.rake are thin wrappers around this.
module AdminTask
  module_function

  def set(username, granting)
    account = User.find_by(username: username)
    return warn("No account named #{username.inspect}.") if account.nil?

    account.update!(admin: granting)
    puts "#{account.username} is #{granting ? 'now an administrator' : 'no longer an administrator'}."
  end

  def list
    names = User.administrators.order(:username).pluck(:username)
    return puts(%(No administrators. Grant one with: bin/rails "admin:grant[username]")) if names.empty?

    puts "Administrators: #{names.join(', ')}"
  end
end
