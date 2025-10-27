# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

task default: %i[rubocop test]

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = ["test/**/*_test.rb"]
  t.verbose = false
end

begin
  require "rubocop/rake_task"
  RuboCop::RakeTask.new
rescue LoadError
  # RuboCop is optional
end
