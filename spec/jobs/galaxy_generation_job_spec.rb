require 'rails_helper'

RSpec.describe GalaxyGenerationJob, type: :job do
  it "builds a galaxy at the requested size" do
    expect { described_class.perform_now(name: "Job Galaxy", size: "tiny") }
      .to change(Galaxy, :count).by(1)

    galaxy = Galaxy.last
    expect(galaxy.name).to eq("Job Galaxy")
    expect(galaxy.size).to eq("tiny")
    # The disc, not the square it is inscribed in.
    expect(galaxy.systems.count).to be < (galaxy.width * galaxy.height)
    expect(galaxy.systems.count).to be_positive
  end

  it "founds the empires it is given" do
    described_class.perform_now(
      name: "Job Galaxy", size: "tiny",
      player_configs: [ { name: "Ada", role: "foundry", username: "job-ada" } ]
    )

    expect(Galaxy.last.empires.count).to eq(1)
  end

  it "defaults to a small galaxy" do
    # A large galaxy is ~125,000 systems, which is exactly why generation runs in a job
    # rather than a request.
    expect(GalaxyGenerator).to receive(:new).with(hash_including(size: "small")).and_call_original
    allow_any_instance_of(GalaxyGenerator).to receive(:generate)

    described_class.perform_now(name: "Defaulted")
  end
end
