# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [8.0.1] - 2025-11-03

### Added
- PostGIS-compatible schema dump support
- Global spatial type registration at module load time
- `valid_type?` override for schema dumper compatibility

### Changed
- **Schema dump format** changed to use actual geometric types (PostGIS-compatible)
  - Before: `t.geometry "location", limit: {type: "point", srid: 4326}`
  - After: `t.point "location", limit: {srid: 4326}`
- `SpatialColumn#type` now returns actual geometric type (`:point`, `:linestring`, etc.) instead of always `:geometry`
- `SpatialColumn#limit` now only contains SRID, not type (type is in `column.type`)
- Moved spatial type registration from instance method to module-level initialization

### Removed
- Removed `register_spatial_types` instance method (now global registration)

### Fixed
- Refactored code to comply with `frozen_string_literal: true` directive
  - Replaced string mutation operations (`<<`) with immutable alternatives
  - Fixed RuboCop style violations (line length, string interpolation)

### Technical Details
- Spatial types (point, linestring, polygon, etc.) registered globally at module load
- Schema dumper validates types using `valid_type?` override
- PostGIS-compatible approach: each geometric type is a distinct Rails type
- Column type information flow: `column.type` returns geometric type, `column.limit` returns SRID only

### Migration Notes
**Schema Dump Changes**: Existing schema.rb files will change format on next `db:schema:dump`:
- Old: `t.geometry "location", limit: {type: "point", srid: 4326}`
- New: `t.point "location", limit: {srid: 4326}`

This is a cosmetic change - both formats work identically. The new format matches PostgreSQL's PostGIS adapter behavior.

## [8.0.0] - 2025-10-27

Initial release of ActiveRecord Trilogis Adapter.

### Features

#### Spatial Data Support
- **Spatial Column Types**: Full support for MySQL spatial types
  - Point, LineString, Polygon
  - MultiPoint, MultiLineString, MultiPolygon
  - Geometry, GeometryCollection
- **SRID Support**: Spatial Reference System Identifier handling
  - Per-column SRID specification in migrations
  - MySQL 8.0+ SRID syntax support
  - Proper axis ordering for geographic coordinates
- **Spatial Indexes**: CREATE/DROP spatial indexes via migrations
- **RGeo Integration**: Seamless conversion between MySQL spatial data and RGeo objects

#### ActiveRecord Integration
- **Trilogy Adapter Extension**: Extends Rails 8.0+ native Trilogy adapter
- **Migration Support**: Extended migration DSL for spatial columns
- **Query Support**: Spatial predicates and functions in ActiveRecord queries
- **Type Casting**: Automatic type conversion for spatial data
- **Schema Dumping**: Proper schema.rb generation with spatial types

#### Core Implementation
- **Dependency Loader**: Universal ActiveRecord module pre-loading
  - Consistent behavior across Ruby 3.2, 3.3, 3.4
  - Handles Ruby 3.4 autoload mechanism changes
  - Explicit module loading in correct dependency order
- **Spatial Column Info**: MySQL INFORMATION_SCHEMA metadata queries
- **Spatial Expressions**: MySQL-specific spatial functions
- **Arel Integration**: Custom Arel visitors for spatial SQL generation
- **Database Tasks**: Proper rake task integration for db:create, db:drop, etc.

### Testing & Quality

- **Test Suite**: Comprehensive minitest-based tests
  - Adapter functionality tests
  - DDL operation tests
  - Spatial query tests
  - Type parsing tests
  - Namespaced model tests
- **Docker Environment**: Complete Docker Compose setup
  - MySQL 8.0 service with spatial support
  - Multi-Ruby version test containers
  - Automated database initialization
- **Continuous Integration**: GitHub Actions workflow
  - Matrix: Ruby 3.2/3.3/3.4 × Rails 8.0
  - RuboCop linting
  - MySQL 8.0 service container
- **Code Quality**: RuboCop with performance and rake plugins
  - Zero offense baseline
  - Gem-specific adapter patterns
  - Integrated into rake default task

### Requirements

- **Ruby**: 3.2, 3.3, or 3.4
- **Rails**: 8.0.x
- **MySQL**: 8.0+
- **RGeo**: ~> 3.0
- **rgeo-activerecord**: ~> 7.0

### License

MIT License - Free and permissive open source license.

### Credits

Based on rgeo-activerecord and inspired by:
- activerecord-postgis-adapter
- activerecord-mysql2rgeo-adapter
