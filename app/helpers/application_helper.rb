module ApplicationHelper
  # Signed figures read better in a HUD: "+78" and "−102" rather than "78"/"-102".
  # Uses a real minus sign so digits stay aligned in tabular columns.
  def number_with_sign(value)
    rounded = value.round
    sign = rounded.negative? ? "−" : "+"

    "#{sign}#{number_with_delimiter(rounded.abs)}"
  end

  def structure_glyph_tone(structure)
    case structure.category
    when "extraction" then structure.resource == :metal ? "text-metal" : "text-crystal"
    when "energy" then "text-amber"
    else "text-ink-2"
    end
  end
end
