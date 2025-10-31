# Build and Publish Guide

This guide covers building and publishing the activerecord-trilogis-adapter gem. The project provides three different ways to build and publish, choose the one that best fits your workflow:

## 🔧 Option 1: Rake Tasks (Recommended for Ruby developers)

The most Ruby-native approach using rake tasks.

### Available Tasks
```bash
# List all gem-related tasks
rake -T gem

# Run validations only
rake gem:validate

# Build gem with full validations
rake gem:build

# Quick build without validations (for testing)  
rake gem:build_quick

# Publish to RubyGems with full validations
rake gem:publish

# Show gem information
rake gem:info

# Clean build artifacts
rake gem:clean

# Bump version interactively and commit
rake gem:bump

# Convenient aliases
rake build      # Same as gem:build
rake release    # Same as gem:publish
```

### Examples
```bash
# Full build and publish workflow
rake gem:validate    # Run tests, linting, git checks
rake gem:build       # Build the gem 
rake gem:publish     # Publish to RubyGems

# Or use the all-in-one command
rake gem:publish     # Does validation + build + publish

# Quick development testing
rake gem:build_quick # Build without validations
```

## ⚙️ Option 2: Makefile (Traditional build tool)

Standard make targets for those who prefer Makefiles.

### Available Targets
```bash
# Show help
make help

# Run individual validations
make test       # Run tests only
make lint       # Run RuboCop only
make validate   # Run all validations

# Build gem with full validations
make build

# Quick build without validations (for testing)
make build-quick

# Publish to RubyGems with full validations  
make publish

# Show gem information
make info

# Clean build artifacts
make clean

# Bump version interactively and commit
make bump

# Install dependencies
make install
```

### Examples
```bash
# Full build and publish workflow
make validate   # Run tests, linting, git checks
make build      # Build the gem
make publish    # Publish to RubyGems

# Quick development testing
make build-quick
```

## 🔍 What Each Validation Includes

All three build systems perform the same comprehensive validations:

### ✅ Test Validation
- Runs the complete Minitest test suite
- Validates all functionality works correctly

### ✅ Code Quality Validation  
- Runs RuboCop linting
- Enforces consistent code style
- Checks for potential issues

### ✅ Git Validation
- Ensures working directory is clean (no uncommitted changes)
- Warns if not on `main` branch (with option to continue)
- Prevents accidental releases from dirty state

### ✅ Build Validation
- Verifies gemspec is valid
- Checks all required files are included
- Ensures gem can be built successfully

## 📦 Build Artifacts

All build methods create gems in the `pkg/` directory:
- `pkg/activerecord-trilogis-adapter-<version>.gem` - The built gem file

Use `make clean` or `rake gem:clean` to remove build artifacts.

## 🚀 Publishing Process

When you run the publish command (any of the three options), it will:

1. **Validate**: Run all tests, linting, and git checks
2. **Build**: Create the gem file
3. **Tag**: Create a git tag for the version  
4. **Push**: Push the tag to the remote repository
5. **Publish**: Upload the gem to RubyGems.org

## 🔖 Version Management

Both build systems (Rake and Make) include interactive version bumping functionality:

### Version Bump Commands

| Tool | Command | Description |
|------|---------|-------------|
| **Rake** | `rake gem:bump` | Interactive version bump with commit |
| **Make** | `make bump` | Interactive version bump with commit |

### Version Bump Process

When you run any version bump command, it will:

1. **Display Current Version**: Shows the current version from `lib/active_record/connection_adapters/trilogis/version.rb`
2. **Interactive Input**: Prompts you to enter the new version
3. **Validation**: Ensures semantic versioning format (e.g., `8.0.1` or `8.1.0-beta.1`)
4. **Update Files**: Modifies both the version file and gemspec with the new version
5. **Git Commit**: Creates a commit with message `chore: bump version to X.Y.Z`
6. **Next Steps**: Provides guidance on building and publishing

### Example Workflow

```bash
# Using rake (recommended for Ruby developers)
rake gem:bump
# Current version: 8.0.0
# Enter new version: 8.0.1
# ✅ Updated version to 8.0.1
# ✅ Version bump committed successfully!

# Build and publish
rake gem:publish
```

## ⚠️ Prerequisites

Before publishing:

1. **RubyGems Account**: Ensure you have a RubyGems.org account
2. **API Key**: Configure your RubyGems API key (`gem signin`)
3. **MFA Setup**: This gem requires MFA for RubyGems (configured in gemspec)
4. **Version Bump**: Use interactive version bump commands or manually update `lib/active_record/connection_adapters/trilogis/version.rb` and `activerecord-trilogis-adapter.gemspec`
5. **Clean Git**: Commit all changes before publishing (version bump commands handle this automatically)
6. **Main Branch**: Recommended to publish from `main` branch

## 🔧 Security Configuration

**Important**: This gem has MFA (Multi-Factor Authentication) enabled for RubyGems publishing for enhanced security. This is configured in `activerecord-trilogis-adapter.gemspec`:

```ruby
spec.metadata["rubygems_mfa_required"] = "true"
```

Make sure you have MFA configured on your RubyGems account before publishing.

## 💡 Recommendations

- **For Ruby developers**: Use rake tasks (most native and Ruby-idiomatic)
- **For traditional workflows**: Use Makefile (universal and widely supported)
- **For quick testing**: Use the `build-quick` variants to skip validations
- **For production releases**: Always use the full validation workflow

Choose the tool that best fits your development workflow and team preferences!