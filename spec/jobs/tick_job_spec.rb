require 'rails_helper'

RSpec.describe TickJob, type: :job do
  let(:galaxy) do
    GalaxyGenerator.new(
      name: "Job Test",
      width: 11,
      height: 11,
      player_configs: [ { name: "Ada", role: "foundry" } ]
    ).generate
  end

  it "processes the galaxy tick" do
    expect(TickProcessor).to receive(:new).with(galaxy).and_call_original

    TickJob.perform_now(galaxy.id)

    expect(galaxy.reload.current_tick).to eq(1)
  end

  it "does nothing for a non-active galaxy" do
    galaxy.update!(status: :completed)

    expect(TickProcessor).not_to receive(:new)

    TickJob.perform_now(galaxy.id)

    expect(galaxy.reload.current_tick).to eq(0)
  end
end
