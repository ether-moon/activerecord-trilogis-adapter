# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
  t.verbose = true
end

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]

# Gem build and publish tasks
namespace :gem do
  desc "Run all pre-publish validations"
  task :validate do
    puts "🔍 Running pre-publish validations..."

    # Run tests
    puts "\n📋 Running tests..."
    Rake::Task[:test].invoke

    # Run linting
    puts "\n🧹 Running RuboCop..."
    Rake::Task[:rubocop].invoke

    # Check git status
    puts "\n📋 Checking git status..."
    unless `git status --porcelain`.strip.empty?
      abort "❌ Git working directory is not clean. Please commit all changes first."
    end

    # Check if we're on main branch
    current_branch = `git rev-parse --abbrev-ref HEAD`.strip
    unless current_branch == "main"
      puts "⚠️  Warning: You're on branch '#{current_branch}', not 'main'"
      print "Continue anyway? (y/N): "
      response = $stdin.gets.chomp.downcase
      abort "❌ Aborted by user" unless %w[y yes].include?(response)
    end

    puts "✅ All validations passed!"
  end

  desc "Build the gem"
  task build: :validate do
    puts "\n🔨 Building gem..."
    Rake::Task["build"].invoke
    puts "✅ Gem built successfully!"
  end

  desc "Publish gem to RubyGems (with validations)"
  task publish: :validate do
    puts "\n📦 Publishing gem to RubyGems..."

    # Build and push
    Rake::Task["release"].invoke
    puts "✅ Gem published successfully!"
  end

  desc "Quick build without validations (for testing)"
  task :build_quick do
    puts "🔨 Quick building gem..."
    Rake::Task["build"].invoke
    puts "✅ Gem built!"
  end

  desc "Clean build artifacts"
  task :clean do
    puts "🧹 Cleaning build artifacts..."
    FileUtils.rm_rf("pkg")
    puts "✅ Build artifacts cleaned!"
  end

  desc "Show gem info"
  task :info do
    require_relative "lib/active_record/connection_adapters/trilogis/version"
    puts "\n📋 Gem Information:"
    puts "  Name: activerecord-trilogis-adapter"
    puts "  Version: #{ActiveRecord::ConnectionAdapters::Trilogis::VERSION}"
    puts "  Built gems: #{Dir.glob('pkg/*.gem').join(', ')}"
    puts "  Git branch: #{`git rev-parse --abbrev-ref HEAD`.strip}"
    puts "  Git status: #{`git status --porcelain`.strip.empty? ? 'clean' : 'dirty'}"
  end

  desc "Bump version interactively and commit"
  task :bump do
    require_relative "lib/active_record/connection_adapters/trilogis/version"

    puts "🔖 Version Bump"
    puts "Current version: #{ActiveRecord::ConnectionAdapters::Trilogis::VERSION}"
    puts ""

    # Get new version from user
    print "Enter new version: "
    new_version = $stdin.gets.chomp.strip

    if new_version.empty?
      puts "❌ No version entered. Aborting."
      exit 1
    end

    # Validate version format (basic semver check)
    unless new_version.match?(/^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?$/)
      puts "❌ Invalid version format. Please use semantic versioning (e.g., 1.2.3 or 1.2.3-alpha.1)"
      exit 1
    end

    # Check if version is different
    if new_version == ActiveRecord::ConnectionAdapters::Trilogis::VERSION
      puts "❌ New version is the same as current version. Aborting."
      exit 1
    end

    # Update version file
    version_file = "lib/active_record/connection_adapters/trilogis/version.rb"
    version_content = File.read(version_file)
    new_content = version_content.gsub(/VERSION = ".*"/, "VERSION = \"#{new_version}\"")

    File.write(version_file, new_content)
    puts "✅ Updated version to #{new_version}"

    # Also update gemspec if version is hardcoded there
    gemspec_file = "activerecord-trilogis-adapter.gemspec"
    gemspec_content = File.read(gemspec_file)
    new_gemspec_content = gemspec_content.gsub(/spec\.version = ".*"/, "spec.version = \"#{new_version}\"")
    File.write(gemspec_file, new_gemspec_content)

    # Create commit
    puts "\n📝 Creating version bump commit..."
    system("git add #{version_file} #{gemspec_file}")
    commit_message = "chore: bump version to #{new_version}"

    if system("git commit -m '#{commit_message}'")
      puts "✅ Version bump committed successfully!"
      puts "\n📋 Next steps:"
      puts "  - Review the changes: git show"
      puts "  - Build and publish: rake gem:publish"
      puts "  - Push to remote: git push && git push --tags"
    else
      puts "❌ Failed to create commit"
      exit 1
    end
  end
end

# Convenient aliases
desc "Build and publish gem (same as gem:publish)"
task release: "gem:publish"

desc "Build gem only (same as gem:build)"
task build: "gem:build"
