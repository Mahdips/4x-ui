# 4X-UI — admin roles & per-inbound usage multiplier

**4X-UI** is a fork of [MHSanaei/3x-ui](https://github.com/MHSanaei/3x-ui), kept
in sync with upstream and extended with two features the upstream panel does not
have:

1. **Per-inbound usage multiplier** (`usageMultiplier`) — count a client's
   traffic as more (or less) than what Xray actually reports.
2. **Limited admin role** — a second sign-in account type that can manage
   inbounds and clients but nothing else.

Everything else is stock 3x-ui, so upstream merges stay painless.

## Why

Upstream 3x-ui is actively maintained but has neither feature. The Heimdall fork
(`HeimdallStudio/Heimdall-Panel`) has both, but stopped tracking upstream months
behind. 4X-UI takes the latest 3x-ui and ports just those two features forward,
rather than rebasing 300 changed files onto a moving target.

## Feature 1: usage multiplier

Each inbound gets a **usage multiplier**. Traffic reported for a client on that
inbound is written to the database multiplied by that number.

| Multiplier | Effect                                |
| ---------- | ------------------------------------- |
| `0` / `1`  | actual usage (default)                |
| `2`        | counts double — quota burns 2× faster |
| `0.5`      | counts half                           |

- The field is per **inbound**, and applies to every client on that inbound.
- A client shared across several inbounds is scaled per inbound.
- Set it in the inbound form (the field sits with the other inbound settings).
- `0` and negative values are treated as `1` (no scaling), so a mis-typed field
  never zeroes out someone's traffic.
- If the scaling step fails for any reason, the **raw** traffic is written
  instead and a warning is logged. Billing never silently stops.

The multiplier affects what the panel records and shows, so it flows into quota
expiry, reset thresholds, Telegram notifications, and subscription limits the
same way raw traffic would.

### How it fits together

- `internal/database/model/model.go` — `Inbound.UsageMultiplier` column.
- `internal/database/model/usage_multiplier.go` — normalize + apply logic.
- `internal/web/service/inbound.go` — normalizes on add/update.
- `internal/web/service/inbound_traffic.go` — scales before the atomic traffic
  write.
- `internal/web/service/inbound_usage_multiplier.go` — resolves which inbound a
  client's email belongs to and what its multiplier is.
- Frontend: `usageMultiplier` on the inbound form (number input, step 0.5).

## Feature 2: admin roles

Two roles:

| Role      | What it can do                                                |
| --------- | ------------------------------------------------------------- |
| `admin`   | Everything (stock 3x-ui behaviour).                          |
| `limited` | Inbounds and clients only.                                    |

A limited admin **cannot** reach:

- Panel settings (general, security, Telegram, email, Discord, subscription)
- Xray configuration
- Server control (start/stop/restart Xray, panel update, logs, DB import)
- Backup and `backuptotgbot`
- API tokens
- Node management (mutating routes) and subscription balancers (create/update/delete)
- The admin accounts page itself

Enforcement is on the **backend** via `middleware.AdminOnly()` on the route
groups, not just hidden menu entries — a limited admin calling a protected
endpoint directly gets `403`. The frontend additionally hides the Settings,
Xray, and API-docs tabs from the sidebar.

The **first account (id 1) is the owner** and always has full control, even if
its stored role is blank or the database predates the `role` column. It cannot
be deleted or disabled.

### Managing admins

Settings → **Panel admins**:

- Create an account, pick the role (defaults to **limited** — creating a new
  full admin is a deliberate choice).
- Enable/disable an account. A disabled account cannot log in and its existing
  sessions are invalidated.
- Delete an account. The owner is protected.

### How it fits together

- `internal/database/model/model.go` — `User.Role` + `User.Enabled`,
  `IsAdmin()`, `IsLoginAllowed()`.
- `internal/database/db.go` — migrations adding `role` and `enabled`, backfilling
  existing accounts as enabled full admins.
- `internal/web/middleware/admin_only.go` — the `403` guard.
- `internal/web/session/session.go` — `IsAdmin(c)`.
- `internal/web/controller/{setting,xray_setting,server,node,sub_balancer,api,index}.go`
  — route splits.
- `internal/web/service/panel/user.go` — `ListAdmins`, `CreateAdmin`,
  `DeleteAdmin`, `SetAdminEnabled`.
- Frontend: `AdminsTab.tsx`, `useCurrentUser.ts`, sidebar filtering, `GET /me`.

## Compatibility

- Database migration is automatic on first start: existing inbounds get
  multiplier `1`, existing accounts become enabled full admins.
- API behaviour for the stock single-admin setup is unchanged; the new endpoints
  are additive.
- Compatible with 3x-ui's subscription, node-sync, and Telegram-bot flows.

## Documentation

The in-panel API docs page documents the new endpoints: `GET /me` and the four
`/panel/api/setting/admins*` routes.

## License

GPL-3.0, inherited from 3x-ui.
