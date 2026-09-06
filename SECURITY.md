# Security Policy

## Reporting a vulnerability

Please do not open a public issue for security problems.

Email **security@nashlabs.ca** with a description, reproduction steps and,
if you have one, a suggested fix. You should get a reply within a few days.

## Scope

Murmur handles text people highlighted, which is often sensitive. The things
most worth reporting:

- Highlighted text reaching disk, logs, or the network unexpectedly.
- License key or API key exposure, including keys leaking into logs.
- Anything letting one user's license key read another user's data.
- Flaws in the Stripe webhook or license validation that grant unpaid access.
- Sidecar or update channel issues that allow code execution.

## Design notes

- **API and license keys** live in the macOS Keychain, never in preferences or
  plain files.
- **The cloud voice proxy** holds the upstream provider key server-side. It is
  never shipped to clients.
- **Row level security** is enabled on every Supabase table. Users can read only
  their own rows, and all writes go through the service role in server routes.
- **The Windows updater** verifies a minisign signature before applying an
  update.

## Supported versions

Only the latest release receives fixes.
