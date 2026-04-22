# NumberGym Workspace

Monorepo for focused trainer apps that share one training engine and app-specific content packages.

## Source Of Truth

Active development happens only in these workspace members:

- `apps/number_gym`
- `packages/trainer_core`
- `packages/number_gym_content`

Frozen stubs that stay in the repo but are not part of the active migration path:

- `apps/verb_gym`
- `packages/verb_gym_content`

The legacy root Flutter app still exists physically while the cutover is in progress, but it is no longer the target architecture and should not receive new feature work.

## Workspace Commands

Run everything from the repository root:

```powershell
pwsh ./tool/bootstrap.ps1
pwsh ./tool/analyze_all.ps1
pwsh ./tool/test_all.ps1
```

Use `-IncludeFrozen` only when you intentionally want to validate the frozen verb stubs as well.

## Repository Layout

- `apps/number_gym`: NumberGym app shell, branding, app-level UI, integration tests.
- `packages/trainer_core`: shared training engine, orchestration, persistence abstractions, reusable UI shell.
- `packages/number_gym_content`: NumberGym content definition and content-specific tests.
- `apps/verb_gym`, `packages/verb_gym_content`: parked scaffolding for the future verb app.
- `tool`: root scripts for bootstrapping and validating the workspace.
- `Docs`: root-level migration and workspace architecture notes.

## Lockfile Policy

- App lockfiles are committed.
- Internal package lockfiles are not treated as source of truth and are ignored.

## Docs

- [Workspace Architecture](Docs/architecture.md)
- [NumberGym App Readme](apps/number_gym/README.md)
