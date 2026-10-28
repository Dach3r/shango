# Contributing to Shango

Thanks for your interest in Shango. This guide covers how to propose and submit changes. For setup, configuration and the full list of conventions, the [README](README.md) is the reference; this file points to it instead of repeating it.

## Before you start

- Read [`docs/product.md`](docs/product.md) (vision, principles, roadmap) and [`docs/architecture.md`](docs/architecture.md) (stack, domain model, conventions).
- Check the real code before assuming a feature exists. The roadmap describes intent, not what is built.
- For anything beyond a small fix (a new feature, a product or architecture change), **open an issue first** and wait for agreement. This avoids work that cannot be merged.
- Never show an unbuilt feature as available in the UI; unbuilt navigation entries are disabled with a "Soon" badge.

## Development setup

Follow [Getting started](README.md#getting-started) in the README. In short:

```bash
git clone https://github.com/Dach3r/shango.git
cd shango
bin/setup
```

`bin/setup` installs dependencies, prepares the database and enables the repository git hooks (`.githooks`), which validate your commit messages locally. Run it once even if you set everything up by hand.

## Making a change

1. Fork the repository and branch from `main`.
2. Keep the change focused: one logical change per pull request, no unrelated cleanups.
3. Follow the [conventions](README.md#conventions). The ones that most often need a second pass:
   - **i18n**: every user-facing string goes in both `en` and `es` locale files; no hard-coded UI text.
   - **Project scope**: domain data is always queried through the current project.
   - **Secrets** use Active Record encryption and are never logged or rendered back unmasked.
   - **Controllers** stay thin; business logic goes in `app/services` using `Serviceable`.
   - **Migrations**: one `create_table` per file, never edit a committed migration, use the real creation timestamp.
   - **UI style**: line design (square corners, hairline borders, no shadows).
4. Ship tests with the change. The suite uses RSpec and coverage (line and branch) must stay at 100%.
5. Update the matching document in `docs/` when behavior changes. Documentation is written in English.
6. Only add dependencies with AGPL-compatible licenses (MIT, BSD, Apache-2.0, LGPL; never GPL-2.0-only).

## Checks

Run everything CI runs before opening the pull request:

```bash
bin/ci
```

Or the individual pieces:

```bash
bundle exec rubocop
bundle exec rspec
```

## Commit messages

Commits use gitmoji + Conventional Commits:

```
<emoji> <type>(<scope>): <subject>
```

Example: `✨ feat(api_client): add digest auth`. The emoji for each type is listed in the [README](README.md#conventions). The format is enforced locally by the `commit-msg` hook and on pull requests by the `Commit lint` workflow, which checks every commit subject.

## Pull requests

- Target `main`.
- Describe what changed and why, and link the related issue.
- CI (security, lint and tests), the commit lint and the contribution terms check must pass. The last one fails until you tick the license checkbox in the pull request description.
- Keep the branch up to date with `main`.

## License and relicensing

Shango is licensed under the [AGPL-3.0](LICENSE). There is nothing to sign: by opening a pull request (and ticking the license checkbox in its template) you agree that:

1. Your contribution is provided under the AGPL-3.0.
2. You grant the maintainers a perpetual, worldwide, irrevocable, royalty-free right to use, modify and distribute your contribution under any other license they choose, including proprietary terms (for example to offer a managed cloud version). You keep the copyright of your work.
3. You have the right to make this contribution, and your employer (if any) does not claim rights over it.

If the project relicenses, the maintainers will notify contributors as a courtesy, but a reply is not required. Versions already published keep the license they were released under.

To make sure we can reach you, keep a valid email in your git commits. You can contact the maintainers at dnorena415@gmail.com. If you do not agree with these terms, please do not open a pull request.
