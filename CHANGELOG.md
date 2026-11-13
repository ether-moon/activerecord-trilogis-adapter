# Changelog

## Unreleased

### Security

- Quote WKT/EWKT values in every spatial Arel string path.
- Require Trilogy >= 2.13.3 and < 3 at runtime, including fixes for multibyte escaping and error-buffer lifetime.
- Require ActiveRecord >= 8.1.4.1 and < 8.2 and Ruby >= 3.3. End support for the gem's 8.0.x line without backports. MySQL 8.0 remains supported alongside 8.4.

### Correctness and migration notes

- Preserve spatial metadata in column identity and YAML caches. Preserve SRID through aliases, schema dumps, and column null/comment changes; recognize MySQL's `geomcollection` name.
- Schema dumps now omit `limit: {srid: 0}` for unrestricted columns. Explicit SRID 0 remains a constraint. Regenerate schema dumps/caches from the live database; an older incorrect dump cannot recover lost constraints.
- Always use longitude/latitude axis order when writing geographic values, including SRIDs outside the previous five-entry list. Existing stored values are not modified. Inspect affected columns using `ST_Longitude`/`ST_Latitude` against known source coordinates. After backup and validation, `ST_SwapXY` can repair rows confirmed to be reversed; do not apply it to all rows indiscriminately.
- Isolate spatial types from plain Trilogy connections and honor registered factories on database reads without adding registrations per connection. Keep existing geographic factory defaults.
- Restore upstream spatial expression signatures/results and quote scalar function arguments for Rails 8.1.
- Retain GeoJSON input with an actionable error if its optional dependency is missing; pass hashes directly to the decoder to avoid JSON parser version coupling. Invalid spatial string casting and legacy no-op migration options remain unchanged.

### Maintenance

- Use randomized tests with ActiveRecord deprecations treated as errors. Add SQL injection, metadata/cache, DDL round-trip, axis-order, factory, and adapter coexistence regressions.
- Remove legacy connection/dependency-loader overrides and the no-op `db:trilogis:setup` task; Rails native loading and database tasks remain.
- Replace custom build/release wrappers with standard Bundler tasks. Keep only MySQL in Compose and check authenticated TCP readiness.
- Remove unused spatial visitor callbacks, the duplicate instance SQL-type parser, obsolete spatial-column hooks, and the unused Docker initialization script. Test the real type constructor and WKT/EWKT/MySQL binary paths.
- Update the remaining `multi_json` development dependency to 1.21.2.
- Lock development dependencies; add dependency audits, monthly grouped dependency updates, and a three-cell CI matrix with default MySQL authentication.


All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [8.1.2] - 2026-03-16

### Changed
- Relaxed the Ruby upper bound from `< 3.5` to `< 5.0` so Bundler can resolve the gem on Ruby 4.x.
- Added Ruby 4.0 to the CI test matrix.

## [8.1.0] - 2025-11-03

### Added
- Rails 8.1.0+ compatibility support
- Nil guards for type registration phase to prevent NoMethodError

### Changed
- **BREAKING**: Minimum Rails version updated to 8.1.0
- **BREAKING**: Rails 8.0 support dropped (follows activerecord-postgis-adapter approach)
- Updated `SpatialColumn#initialize` signature to include `cast_type` parameter (Rails 8.1 Column API)
- Updated `SchemaStatements#build_spatial_column` to lookup and pass `cast_type` when creating spatial columns
- Enhanced nil safety in `spatial?` method to handle type registration phase
- `Type::Spatial#spatial_factory` handles frozen objects for Rails 8.1 Ractor compatibility

### Dependencies
- Updated `activerecord` dependency: `~> 8.0` → `~> 8.1`
- Updated `rgeo-activerecord` dependency: `~> 8.0` → `~> 8.1`

### Technical Details
- `SpatialColumn#initialize` now expects: `(name, cast_type, default, sql_type_metadata, ...)`
- Added guard against nil `cast_type` during OID type registration
- Added guard against nil `sql_type_metadata` in spatial type checking
- Frozen Type::Spatial objects skip instance variable caching to avoid FrozenError
- Schema dumper compatibility maintained with `cast_type` lookup as "geometry"

### Migration Guide
Users upgrading from Rails 8.0 should update to Rails 8.1+ before upgrading this gem.

**Breaking Change**: This version requires Rails 8.1.0 or higher. For Rails 8.0 support, use version 8.0.1.

## [8.0.2] - 2025-11-03

### Fixed
- Spatial columns now silently ignore `default:` option (MySQL limitation)
- Schema dumps no longer include `default:` for spatial columns
- Prevents SQL syntax errors when using `default:` in migrations

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
