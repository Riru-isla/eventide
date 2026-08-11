FactoryBot.define do
  factory :user do
    sequence(:username) { |n| "user#{n}" }
    password { "eventide" }
  end
end
