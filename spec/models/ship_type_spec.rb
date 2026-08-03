require 'rails_helper'

RSpec.describe ShipType, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name) }
    it { is_expected.to validate_numericality_of(:metal_cost).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:crystal_cost).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:energy_cost).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:attack).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:defense).is_greater_than_or_equal_to(0) }
    it { is_expected.to validate_numericality_of(:speed).is_greater_than_or_equal_to(0) }
  end
end
