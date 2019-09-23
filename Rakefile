# frozen_string_literal: true

require 'rspec/core/rake_task'
require 'rubocop/rake_task'

Dir.glob('tasks/*.rake').each do |tasks|
  load tasks
end

RSpec::Core::RakeTask.new(:spec)

RuboCop::RakeTask.new do |task|
  task.options = %w[-c .rubocop.yml]
end

task default: %i[rubocop spec]
