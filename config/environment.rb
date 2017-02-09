# Load the Rails application.
require_relative 'application'

app_environment_variables = File.join(Rails.root, '.env')
if File.exists?(app_environment_variables)
  lines = File.readlines(app_environment_variables)
  lines.each do |line|
    line.chomp!
    next if line.empty? or line[0] == '#'
    parts = line.partition '='
    raise "Wrong line: #{line} in #{app_environment_variables}" if parts.last.empty?
    ENV[parts.first] = parts.last
  end
end

# Initialize the Rails application.
Rails.application.initialize!
