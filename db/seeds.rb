# Loads every db/seeds/base/*.seeds.rb (all environments) and then every db/seeds/<environment>/*.seeds.rb, in
# alphabetical order. Seeds must be idempotent so `bin/rails db:seed` can run at any point.
#
# Add a file to db/seeds/base for records the app needs everywhere, or to db/seeds/<environment> for one environment
# only (for example db/seeds/development/performance_account.seeds.rb).
%w[base].push(Rails.env.to_s).uniq.each do |scope|
  Rails.root.glob("db/seeds/#{scope}/*.seeds.rb").sort.each do |file|
    puts "== Seeding #{scope}/#{file.basename(".seeds.rb")}"
    load file
  end
end
