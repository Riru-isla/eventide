require 'rails_helper'

RSpec.describe AdminTask, type: :service do
  describe ".set" do
    it "grants rights to a named account" do
      account = create(:user, username: "ada")

      expect { described_class.set("ada", true) }.to output(/ada is now an administrator/).to_stdout
      expect(account.reload).to be_admin
    end

    it "withdraws them again" do
      account = create(:user, username: "ada", admin: true)

      expect { described_class.set("ada", false) }.to output(/no longer an administrator/).to_stdout
      expect(account.reload).not_to be_admin
    end

    it "says so rather than failing when the account does not exist" do
      expect { described_class.set("nobody", true) }.to output(/No account named "nobody"/).to_stderr
    end
  end

  describe ".list" do
    it "names the administrators" do
      create(:user, username: "root", admin: true)
      create(:user, username: "ada")

      expect { described_class.list }.to output(/Administrators: root/).to_stdout
    end

    it "explains how to make one when there are none" do
      create(:user, username: "ada")

      expect { described_class.list }.to output(/admin:grant/).to_stdout
    end
  end
end
