# Security policy

Only the latest 8.1.x release line is maintained. Version 8.0.x is end of life and will not receive backports; users must migrate to the maintained Rails/adapter line.

Version 8.1.3 fixes unsafe quoting of spatial WKT/EWKT strings and requires Trilogy >= 2.13.3. Version 8.1.2 is not a patched release. Upgrade to 8.1.3 or later. Until the patched adapter is deployed, avoid passing untrusted strings to spatial Arel functions, and independently update Trilogy.

Report vulnerabilities privately through the repository's GitHub Security tab when private reporting is enabled, or contact the maintainer at `chipseru@gmail.com`. Do not include production data or credentials in reports.

The adapter's spatial quoting issue is distinct from Trilogy's [multibyte escaping advisory](https://github.com/trilogy-libraries/trilogy/security/advisories/GHSA-744p-w4gc-m3gh). Updating Trilogy alone does not fix the adapter's spatial visitor.
