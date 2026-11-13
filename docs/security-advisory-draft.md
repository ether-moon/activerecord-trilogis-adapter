# Draft: SQL injection in spatial string arguments

Status: local draft, not submitted or published. Confirm affected release tags before advisory publication.

## Impact

The spatial Arel visitor in version 8.1.2 interpolates WKT/EWKT strings into `ST_GeomFromText` without database quoting. An application that passes attacker-controlled strings to `st_distance` and related spatial APIs may execute unintended SQL. This path is independent of Trilogy's multibyte escaping vulnerability.

The prior investigation identified 8.0.0 through 8.1.2 as affected. This implementation directly reproduces the issue on the current 8.1.2 source. Earlier release tags still need publication-time verification.

## Fix

All spatial WKT/EWKT strings pass through the connection's quoting implementation. Regression tests cover spatial predicates, `Arel.spatial`, generic spatial `NamedFunction`, EWKT, and an executed predicate payload against local MySQL. Trilogy >= 2.13.3 is also required at runtime.

Patched version: 8.1.3. The 8.0.x line will not receive a backport.

## Temporary mitigation

Avoid passing untrusted strings into spatial Arel APIs until the adapter fix is deployed. Construct validated RGeo objects at the application boundary. Update Trilogy independently to address its own escaping vulnerability.
