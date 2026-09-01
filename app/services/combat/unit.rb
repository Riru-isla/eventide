module Combat
  # What one kind of combatant brings to a battle.
  #
  # Ships and ground defences are deliberately the same shape: the resolver has no idea
  # which it is holding, so adding orbital platforms or anything else later is a catalogue
  # entry rather than a change to how a fight works.
  #
  # `damage` carries a figure against each layer. They are equal for every unit today, so
  # it degenerates to plain sequential depletion — but the resolver already honours them,
  # so weapons that are good against shields and poor against hull need no new code.
  # Ground defences are the same shape as ships on purpose. Orbital platforms, or anything
  # else that fights, are a new entry here rather than a change to how a battle works.
  CATEGORIES = %w[ship ground_defence].freeze

  Unit = Data.define(:key, :name, :category, :shield, :armour, :hull, :damage, :signature) do
    def ship? = category == "ship"

    # Immobile things only fight where they stand.
    def mobile? = ship?

    def damage_against(layer) = damage.fetch(layer)

    # How much fire this hull draws relative to anything else standing beside it. A heavy
    # ship pulls shots away from the fragile ones behind it, which is the only thing that
    # makes a defensive hull worth building in a fleet somebody else is also flying in.
    #
    # Deliberately not proportional to integrity: a hull that soaked exactly in proportion
    # to what it can take would screen nobody, it would just be a bigger corvette.
    def draw = signature

    def total_integrity = shield + armour + hull
  end
end
