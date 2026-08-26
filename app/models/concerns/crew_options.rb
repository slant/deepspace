# frozen_string_literal: true

# Officer creation options from The Long Way Home RPG v1.43, page 6
module CrewOptions
  SPECIALTIES = [
    "Artisan", "Assassin", "Bio Engineer", "Bounty Hunter", "Chef", "Chemist",
    "Dark Matter Specialist", "Diplomat", "Doctor", "Freelancer", "Hacker",
    "Musician", "Pilot", "Politician", "Psychic", "Researcher", "Roboticist",
    "Scholar", "Smuggler", "Soldier", "Spy", "Scientist", "Xeno-Biologist"
  ].freeze

  ATTRIBUTES_A = [
    "Addicted", "Apathetic", "Conceited", "Coward", "Gluttonous", "Greedy",
    "Impulsive", "Inflexible", "Insincere", "Lazy", "Loner", "Mistrusting",
    "Narcissistic", "Obsessive", "Proud", "Rebellious", "Reckless", "Selfish",
    "Short-tempered", "Stubborn", "Superficial", "Weak", "Xenophobic"
  ].freeze

  ATTRIBUTES_B = [
    "Altruistic", "Brave", "Charming", "Clever", "Confident", "Dreamer",
    "Generous", "Improviser", "Independent", "Judicious", "Loyal", "Lucky",
    "Observant", "Optimistic", "Patient", "Persistent", "Rational", "Reliable",
    "Resourceful", "Selfless", "Stoic", "Strong", "Upbeat"
  ].freeze

  SHIP_LABELS = {
    "halcyon" => "Halcyon",
    "athena_mk_ii" => "Athena Mk. II",
    "ag_8" => "AG-8",
    "mononoaware" => "Mononoaware",
    "project_union" => "Project Union"
  }.freeze
end
