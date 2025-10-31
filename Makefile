# ActiveRecord Trilogis Adapter Gem Build and Publish Makefile

.PHONY: help build publish build-quick validate clean info test lint bump

# Default target
help:
	@echo "ActiveRecord Trilogis Adapter Gem Build and Publish Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  build        Build gem with full validations (tests, linting, git checks)"
	@echo "  publish      Publish gem to RubyGems with full validations"
	@echo "  build-quick  Build gem without validations (for testing)"
	@echo "  validate     Run all validations without building"
	@echo "  test         Run tests only"
	@echo "  lint         Run RuboCop only"
	@echo "  info         Show gem and repository information"
	@echo "  clean        Clean build artifacts"
	@echo "  bump         Bump version interactively and commit"
	@echo "  help         Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build          # Build gem with validations"
	@echo "  make publish        # Build and publish to RubyGems"
	@echo "  make bump           # Bump version interactively"
	@echo "  make info           # Show current gem info"

# Run tests
test:
	@echo "📋 Running tests..."
	@bundle exec rake test
	@echo "✅ All tests passed"

# Run linting
lint:
	@echo "🧹 Running RuboCop..."
	@bundle exec rubocop
	@echo "✅ RuboCop checks passed"

# Validate git status
validate-git:
	@echo "📋 Checking git status..."
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "❌ Git working directory is not clean. Please commit all changes first."; \
		exit 1; \
	fi
	@echo "✅ Git working directory is clean"
	@current_branch=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$current_branch" != "main" ]; then \
		echo "⚠️  Warning: You're on branch '$$current_branch', not 'main'"; \
		read -p "Continue anyway? (y/N): " response; \
		if [ "$$response" != "y" ] && [ "$$response" != "Y" ]; then \
			echo "❌ Aborted by user"; \
			exit 1; \
		fi; \
	fi
	@echo "✅ Git branch check passed"

# Run all validations
validate: test lint validate-git
	@echo "✅ All validations passed!"

# Build gem with validations
build: validate
	@echo "🔨 Building gem..."
	@bundle exec rake build
	@echo "✅ Gem built successfully!"

# Build gem without validations (for testing)
build-quick:
	@echo "🔨 Quick building gem (no validations)..."
	@bundle exec rake build
	@echo "✅ Gem built!"

# Publish gem to RubyGems
publish: validate
	@echo "📦 Publishing gem to RubyGems..."
	@bundle exec rake release
	@echo "✅ Gem published successfully!"

# Show gem information
info:
	@echo "📋 Gem Information:"
	@echo "  Name: activerecord-trilogis-adapter"
	@echo "  Version: $$(ruby -r ./lib/active_record/connection_adapters/trilogis/version -e 'puts ActiveRecord::ConnectionAdapters::Trilogis::VERSION')"
	@echo "  Built gems: $$(ls pkg/*.gem 2>/dev/null || echo 'none')"
	@echo "  Git branch: $$(git rev-parse --abbrev-ref HEAD)"
	@git_status=$$(git status --porcelain); \
	if [ -z "$$git_status" ]; then \
		echo "  Git status: clean"; \
	else \
		echo "  Git status: dirty"; \
	fi

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf pkg/
	@echo "✅ Build artifacts cleaned!"

# Bump version interactively and commit
bump:
	@echo "🔖 Version Bump"
	@current_version=$$(ruby -r ./lib/active_record/connection_adapters/trilogis/version -e 'puts ActiveRecord::ConnectionAdapters::Trilogis::VERSION'); \
	echo "Current version: $$current_version"; \
	echo ""; \
	read -p "Enter new version: " new_version; \
	if [ -z "$$new_version" ]; then \
		echo "❌ No version entered. Aborting."; \
		exit 1; \
	fi; \
	if ! echo "$$new_version" | grep -qE "^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$$"; then \
		echo "❌ Invalid version format. Please use semantic versioning (e.g., 1.2.3 or 1.2.3-alpha.1)"; \
		exit 1; \
	fi; \
	if [ "$$new_version" = "$$current_version" ]; then \
		echo "❌ New version is the same as current version. Aborting."; \
		exit 1; \
	fi; \
	version_file="lib/active_record/connection_adapters/trilogis/version.rb"; \
	gemspec_file="activerecord-trilogis-adapter.gemspec"; \
	sed -i.bak "s/VERSION = \".*\"/VERSION = \"$$new_version\"/" "$$version_file" && rm "$$version_file.bak"; \
	sed -i.bak "s/spec.version = \".*\"/spec.version = \"$$new_version\"/" "$$gemspec_file" && rm "$$gemspec_file.bak"; \
	echo "✅ Updated version to $$new_version"; \
	echo ""; \
	echo "📝 Creating version bump commit..."; \
	git add "$$version_file" "$$gemspec_file"; \
	commit_message="chore: bump version to $$new_version"; \
	if git commit -m "$$commit_message"; then \
		echo "✅ Version bump committed successfully!"; \
		echo ""; \
		echo "📋 Next steps:"; \
		echo "  - Review the changes: git show"; \
		echo "  - Build and publish: make publish"; \
		echo "  - Push to remote: git push && git push --tags"; \
	else \
		echo "❌ Failed to create commit"; \
		exit 1; \
	fi

# Install dependencies
install:
	@echo "📦 Installing dependencies..."
	@bundle install
	@echo "✅ Dependencies installed!"