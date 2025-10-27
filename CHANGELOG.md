# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
