# NumberGym Workspace

Monorepo for focused trainer apps that share one training engine and app-specific content packages.

## Source Of Truth

Active development happens only in these workspace members:

- `apps/number_gym`
- `packages/trainer_core`
- `packages/number_gym_content`

Scaffold members that are part of the target architecture but still incomplete:

- `apps/verb_gym`
- `packages/verb_gym_content`

The root workspace is now orchestration-only: scripts, docs, and historical platform folders live here, but product Dart code belongs only in `apps/*` and `packages/*`.

## Workspace Commands

Run everything from the repository root:

```powershell
pwsh ./tool/bootstrap.ps1
pwsh ./tool/analyze_all.ps1
pwsh ./tool/test_all.ps1
pwsh ./tool/run_number_gym.ps1
pwsh ./tool/run_verb_gym.ps1
pwsh ./tool/publish_number_gym_web.ps1
pwsh ./tool/publish_verb_gym_web.ps1
```

Use `-IncludeScaffolds` when you want root validation scripts to include the VerbGym scaffold as well.

## Repository Layout

- `apps/number_gym`: NumberGym app shell, branding, app-level UI, integration tests.
- `packages/trainer_core`: shared training engine, orchestration, persistence abstractions, reusable UI shell.
- `packages/number_gym_content`: NumberGym content definition and content-specific tests.
- `apps/verb_gym`, `packages/verb_gym_content`: VerbGym app shell/content scaffold with its own branding assets.
- `tool`: root scripts for bootstrapping and validating the workspace.
- `Docs`: root-level migration and workspace architecture notes.

## Brand Assets

- App-specific identity lives in each app shell under `apps/<app>/assets/images/branding/`.
- Shared visuals that intentionally stay the same for an app remain in the regular app asset folders such as `apps/<app>/assets/images/`, `goal_rewards/`, and `session_rewards/`.
- Use semantic file names inside each app branding folder so code can stay stable across apps. The current app name wordmark path is `assets/images/branding/wordmark.png`.
- Do not add new app-specific identity to `packages/trainer_core`.

## Lockfile Policy

- App lockfiles are committed.
- Internal package lockfiles are not treated as source of truth and are ignored.

## Shipping Commands

- Run NumberGym on a connected phone: `pwsh ./tool/run_number_gym.ps1 -DeviceId <device-id>`
- Run VerbGym on a connected phone: `pwsh ./tool/run_verb_gym.ps1 -DeviceId <device-id>`
- Publish NumberGym web to GitHub Pages: `pwsh ./tool/publish_number_gym_web.ps1`
- Publish VerbGym web to GitHub Pages subpath: `pwsh ./tool/publish_verb_gym_web.ps1`
- Windows bat launchers: `deploy_number_gym_web_pages.bat`, `deploy_verb_gym_web_pages.bat`

## Docs

- [Workspace Architecture](Docs/architecture.md)
- [NumberGym App Readme](apps/number_gym/README.md)
