# Trilogis ActiveRecord Adapter

[![Gem Version](https://badge.fury.io/rb/activerecord-trilogis-adapter.svg)](https://badge.fury.io/rb/activerecord-trilogis-adapter)
[![CI](https://github.com/ether-moon/activerecord-trilogis-adapter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ether-moon/activerecord-trilogis-adapter/actions/workflows/ci.yml)

ActiveRecord adapter for MySQL with spatial extensions, built on Trilogy. Extends the Rails 8.0+ built-in Trilogy adapter with spatial capabilities using the [RGeo](http://github.com/rgeo/rgeo) library.

## Overview

The adapter provides three core capabilities:

1. **Spatial Migrations** - Extended ActiveRecord migration syntax for spatial columns and indexes
2. **Spatial Type Casting** - Automatic conversion between MySQL spatial data and RGeo geometry objects
3. **Spatial Queries** - Support for spatial predicates and functions in ActiveRecord queries

## Requirements

| Component | Version | Notes |
|-----------|---------|-------|
| Ruby | 3.2, 3.3, 3.4 | All versions fully supported |
| Rails | 8.0.x | Rails 7.x not supported |
| MySQL | 8.0+ | Spatial support required |
| RGeo | ~> 3.0 | Spatial data handling |

### Version Compatibility

| Ruby | Rails 8.0 | CI Tested |
|------|-----------|-----------|
| 3.2  | ✅ | ✅ |
| 3.3  | ✅ | ✅ |
| 3.4  | ✅ | ✅ |

**Dependency Loader**: Universal ActiveRecord module pre-loading ensures consistent behavior across Ruby 3.2-3.4, handling Ruby 3.4's autoload mechanism changes.

## Installation

Add to your Gemfile:

```ruby
gem 'activerecord-trilogis-adapter', '~> 8.0'
```

## Configuration

Configure your `database.yml`:

```yaml
development:
  adapter: trilogis
  host: localhost
  database: myapp_development
  username: root
  password:
  port: 3306
```

## Usage

### Migrations

```ruby
class CreatePlaces < ActiveRecord::Migration[8.0]
  def change
    create_table :places do |t|
      t.string :name
      t.point :location, null: false, srid: 4326
      t.geometry :shape
      t.linestring :route
      t.polygon :area
      t.multipoint :points
      t.multilinestring :routes
      t.multipolygon :areas

      t.timestamps
    end

    # Add spatial index
    add_index :places, :location, type: :spatial
    add_index :places, :shape, type: :spatial
  end
end
```

### Models

```ruby
class Place < ApplicationRecord
  # Spatial columns automatically use RGeo types

  # You can specify a custom factory for a column
  set_rgeo_factory_for_column :location,
    RGeo::Geographic.spherical_factory(srid: 4326)
end

# Create records with RGeo objects
factory = RGeo::Cartesian.factory(srid: 4326)
point = factory.point(139.7, 35.7)  # Tokyo

place = Place.create!(
  name: "Tokyo",
  location: point,
  area: factory.parse_wkt("POLYGON((...))")
)

# Or use WKT strings directly
place = Place.create!(
  name: "Mt. Fuji",
  location: "POINT(138.7274 35.3606)"
)

# Or GeoJSON-like hashes
place = Place.create!(
  name: "Osaka",
  location: { type: "Point", coordinates: [135.5, 34.7] }
)
```

### Spatial Queries

```ruby
# Find places within a bounding box
bounds = "POLYGON((139 35, 140 35, 140 36, 139 36, 139 35))"
Place.where("ST_Within(location, ST_GeomFromText(?))", bounds)

# Find places within distance (in meters for geographic data)
tokyo = "POINT(139.7 35.7)"
Place.where("ST_Distance(location, ST_GeomFromText(?)) < ?", tokyo, 50000)

# Use Arel for more complex queries
places = Place.arel_table
predicate = Arel::Nodes::NamedFunction.new(
  "ST_Contains",
  [Arel::Nodes::Quoted.new(bounds), places[:location]]
)
Place.where(predicate)

# Select with spatial functions
Place.select("*, ST_AsText(location) as location_wkt, ST_Area(area) as area_size")

# Spatial joins
Place.joins(:regions).where("ST_Contains(regions.boundary, places.location)")
```

## Spatial Types

| Type | Description |
|------|-------------|
| `geometry` | Generic geometry type |
| `point` | 2D point (x, y) |
| `linestring` | Sequence of points forming a line |
| `polygon` | Closed shape with exterior and holes |
| `multipoint` | Collection of points |
| `multilinestring` | Collection of linestrings |
| `multipolygon` | Collection of polygons |
| `geometrycollection` | Mixed collection of geometries |

## Spatial Functions

Common MySQL spatial functions are supported:

- `ST_Contains`, `ST_Within`, `ST_Intersects`, `ST_Touches`, `ST_Crosses`
- `ST_Distance`, `ST_Area`, `ST_Length`
- `ST_Buffer`, `ST_Envelope`, `ST_Centroid`
- `ST_AsText`, `ST_AsBinary`, `ST_GeomFromText`, `ST_GeomFromWKB`
- `ST_SRID`, `ST_Transform` (MySQL 8.0+)

## RGeo Integration

The adapter integrates with RGeo for geometry handling:

```ruby
# Configure a global factory
RGeo::ActiveRecord::SpatialFactoryStore.instance.tap do |config|
  config.default = RGeo::Cartesian.preferred_factory(srid: 4326)

  # Use geographic (spherical) calculations for 4326
  config.register(
    RGeo::Geographic.spherical_factory(srid: 4326),
    geo_type: "point",
    srid: 4326
  )
end
```

## Advanced Features

### Custom SRID

```ruby
class CreateCities < ActiveRecord::Migration[8.0]
  def change
    create_table :cities do |t|
      # Japanese Plane Rectangular CS VI (SRID: 2448)
      t.point :location, srid: 2448
    end
  end
end
```

### Geographic vs Geometric

```ruby
# Geographic (spherical) calculations - better for lat/lon
factory = RGeo::Geographic.spherical_factory(srid: 4326)

# Geometric (cartesian) calculations - better for projected coordinates
factory = RGeo::Cartesian.preferred_factory(srid: 2448)
```

## Testing

### Continuous Integration

GitHub Actions CI pipeline with comprehensive testing:

**Jobs:**
- **Lint**: RuboCop code quality (Ruby 3.4)
- **Test Matrix**: Ruby 3.2/3.3/3.4 × Rails 8.0 × MySQL 8.0

**Triggers:**
- Push to `main` or `develop`
- Pull requests to `main` or `develop`

**Infrastructure:**
- MySQL 8.0 service container
- Real database integration tests
- Automated schema creation and validation

### Using Docker (Recommended)

Docker Compose provides a complete testing environment with MySQL 8.0:

```bash
# Run all tests
docker compose up test

# Run specific test file
docker compose run --rm test bundle exec ruby -Itest test/basic_test.rb

# Interactive shell for debugging
docker compose run --rm test bash

# Start only MySQL service
docker compose up -d mysql
```

**Prerequisites:** Docker Desktop with Compose v3.8+

### Local Testing

```bash
# Run all tests
bundle exec rake test

# Run RuboCop
bundle exec rake rubocop

# Run both tests and RuboCop
bundle exec rake

# Auto-fix RuboCop offenses
bundle exec rubocop --autocorrect-all

# Run specific test file
bundle exec ruby -Itest test/basic_test.rb

# With custom database configuration
DB_HOST=localhost DB_USERNAME=root DB_PASSWORD=pass bundle exec rake test
```

**Prerequisites for local testing:**
- MySQL 8.0+ running locally
- Test database created: `trilogis_adapter_test`
- User with appropriate permissions

## Development

```bash
# Setup
bundle install

# Run tests
bundle exec rake test

# Build gem
bundle exec rake build

# Console
bundle console
```

## Migration Guide

### Upgrading to 8.0

**Prerequisites:**
- Rails 8.0+ (Rails 7.x not supported)
- Ruby 3.2, 3.3, or 3.4

**Steps:**
1. Update Gemfile: `gem 'activerecord-trilogis-adapter', '~> 8.0'`
2. Run: `bundle update activerecord-trilogis-adapter`
3. Verify Rails version: `bundle info rails` (must be 8.0+)
4. Test: `bundle exec rake test`

**API Compatibility:** No code changes required - adapter API remains backward compatible

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/ether-moon/activerecord-trilogis-adapter

## License

MIT License. See LICENSE.txt for details.

## Credits

Based on the [rgeo-activerecord](https://github.com/rgeo/rgeo-activerecord) gem
and inspired by:
- [activerecord-postgis-adapter](https://github.com/rgeo/activerecord-postgis-adapter) - PostGIS adapter for ActiveRecord
- [activerecord-mysql2rgeo-adapter](https://github.com/stadia/activerecord-mysql2rgeo-adapter) - MySQL2 spatial adapter
