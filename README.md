# ActiveRecord Trilogis Adapter

MySQL spatial columns and RGeo queries on Rails' Trilogy adapter.

Version 8.1.3 includes the security fixes described below. Version 8.1.2 does not contain these fixes; upgrade to 8.1.3 or later.

## Support

- Maintain only the 8.1.x gem line. The 8.0.x line is end of life, with no backports.
- Ruby >= 3.3, ActiveRecord >= 8.1.4.1 and < 8.2, Trilogy >= 2.13.3 and < 3.
- MySQL 8.0 and 8.4. MySQL 5.7 and MariaDB are not supported.
- CI covers Ruby 3.3/4.0 with MySQL 8.0, plus Ruby 4.0 with MySQL 8.4.

## Configure

Add `activerecord-trilogis-adapter` to your Gemfile. Use `adapter: trilogis` in `config/database.yml` with your normal MySQL connection settings and `encoding: utf8mb4`. Trilogy is a runtime dependency; no separate adapter gem is needed.

## Spatial columns and queries

```ruby
create_table :places do |t|
  t.string :name
  t.point :location, srid: 4326, null: false
  t.index :location, type: :spatial
end
```

```ruby
class Place < ActiveRecord::Base
end

factory = RGeo::Geographic.spherical_factory(srid: 4326)
place = Place.create!(name: "Tokyo", location: factory.point(139.7, 35.7))
place.reload.location.longitude # 139.7
place.location.latitude        # 35.7

# EWKT includes the coordinate system; plain WKT uses the column's SRID.
place.update!(location: "SRID=4326;POINT(139.7 35.7)")
location = Place.arel_table[:location]
Place.where(location.st_distance_sphere(factory.point(139.7, 35.7)).lt(1000))
```

Coordinates are longitude/latitude for geographic SRIDs and X/Y for projected SRIDs. Supported types are `geometry`, `point`, `linestring`, `polygon`, `multipoint`, `multilinestring`, `multipolygon`, and `geometrycollection`. Underscored aliases such as `multi_polygon` also work in `t.column`, shortcut methods, and `add_column`.

Omitting `srid:` leaves the column unrestricted. Explicit `srid: 0` restricts it to SRID 0. Schema dumps preserve this distinction. Legacy `has_z`, `has_m`, and `geographic` migration options remain no-ops; MySQL values are two-dimensional.

Standard WKB hex input uses the column's SRID. MySQL-prefixed WKB keeps its stored SRID. Temporary tables have no spatial metadata in INFORMATION_SCHEMA, so their column introspection falls back to the SQL type without reporting an SRID constraint.

Custom factories can be registered through `RGeo::ActiveRecord::SpatialFactoryStore.instance.register(factory, geo_type: "point", srid: 4326)`. They apply to parsing and database reads. GeoJSON hashes require the optional `rgeo-geojson` gem and `require "rgeo/geo_json"`; missing that library raises `ArgumentError`. Invalid WKT continues to cast to `nil` for compatibility.

## Development

Install Ruby, a MySQL client (`mysql` and `mysqldump`), and GEOS for RGeo. Then:

```sh
bundle install
docker compose up -d --wait mysql
export MYSQL_PASSWORD=local
bundle exec rake
bundle exec bundler-audit check --update
COVERAGE=1 bundle exec rake test
bundle exec rake build
```

`MYSQL_HOST`, `MYSQL_PORT`, `MYSQL_USER`, `MYSQL_PASSWORD`, and `MYSQL_DATABASE` override test connection settings. Tests create/drop tables and a task-test database: use a dedicated local MySQL server. The Compose volume persists its original credentials; changing YAML does not change an existing database user's password.

Commit `Gemfile.lock` updates with dependency changes. Coverage is optional and has no percentage gate. Build uses Bundler's standard task. Before publishing, update `spec.version` in `activerecord-trilogis-adapter.gemspec` to the approved release version, run `bundle install` to update `Gemfile.lock`, and commit both files. After validation and release approval, maintainers run `bundle exec rake release`; it creates/pushes the release tag and publishes the gem.

See [CHANGELOG.md](CHANGELOG.md) for migration notes and [SECURITY.md](SECURITY.md) for the support and reporting policy.
