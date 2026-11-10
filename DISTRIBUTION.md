# Distribution

Muninn ships two ways. The first is the Mac App Store, released from the **build box**. The second is a **Developer ID-signed,
notarized** build attached to a GitHub Release. This is the author's release process; you don't need any of it to build or run Muninn
(see the README).

| Channel | Command | Where it runs |
|---|---|---|
| Mac App Store (app id 6759760573, bundle `blue.luci.Muninn`) | `make release`, or its steps (below) | the build box only |
| GitHub Releases (Developer ID, notarized) | `make github-release` | any machine with the certificate and `gh` |

## GitHub Releases: `make github-release`

```sh
make github-release
```

`scripts/direct_release.sh` then: archives in Release with the stamped version, exports with the Developer ID method, notarizes with
`notarytool` (waiting for Apple's verdict), staples the ticket, checks it with Gatekeeper's own assessment, zips it, and runs
`gh release create` for the tag `v<VERSION>` (or uploads over an existing release for that tag). The binary is never committed.

The marketing version is `1.0.<commit count>` and the build number is the commit count, so a release always matches a commit.
`make github-release` refuses a dirty working tree for that reason; push before you release.

### One-time setup

- A **Developer ID Application** certificate for your team (Xcode > Settings > Accounts > Manage Certificates, or developer.apple.com).
- `TEAM` (and `BUNDLE_ID`) in `make/local.mk`; see `make/local.mk.example`.
- Notarization credentials, either:
  - a keychain profile: `xcrun notarytool store-credentials muninn-notary`, then `export NOTARY_PROFILE=muninn-notary`; or
  - an App Store Connect API key: `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_FILEPATH` in your environment.
- The `gh` CLI, signed in (`gh auth login`), and `xcodegen` (`brew install xcodegen`).

### Notes

- This build has no updater: the release notes tell people to download a newer release.
- Untested until the first run.

## The Mac App Store, from the build box

The store targets live in `make/store.mk`. The root Makefile includes that file only when `make/local.mk` declares
`BOX_NAME := prod-build`, so on any other machine they do not exist (`No rule to make target`). The App Store Connect API key must
only ever live on the build box, and is read from the environment, never from a file in this repository:

```sh
# ~/.zshenv on the build box
export ASC_KEY_ID="XXXXXXXXXX"
export ASC_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export ASC_KEY_FILEPATH="$HOME/.secrets/AuthKey_XXXXXXXXXX.p8"
```

Copy `make/local.mk.example` to `make/local.mk` (gitignored) and set `BOX_NAME := prod-build`.

The build number is `git rev-list --count HEAD` and the marketing version is `1.0.<that number>`, which is also the App Store
version string. `make github-release` is the same on the box as everywhere else; `store.mk` does not redefine it.

### `make release`

1. **Gate:** Apple allows no new version while one is waiting for or in App Review, so `make release` stops before building if that is
   the state. Wait for the result, or `make withdraw` (loses the place in the queue; `DRY=1` previews) and run again.
2. **`testflight`:** preflight, `pull` (refuses a dirty tree, then `git pull --ff-only`), the duplicate-build check
   (`scripts/asc_build_check.ts`), archive, and export with `destination: upload` (`make/ExportOptions-upload.plist`): the export is the upload.
3. **`store-setup-apply`:** the app's one-time settings from `listing/app.json`: content rights, category, age rating, price. It says
   nothing about availability, so where the live app is sold never changes.
4. **`listing-apply`:** the listing text from `listing/metadata.json`, on an editable version named exactly `VERSION`.
5. **`screenshots-apply`:** the screenshots from `listing/screenshots/`. A locale with no local PNGs is left as it is.
6. **`submit`:** waits for Apple to finish processing the build, attaches it and sends it to App Review (`DRY=1` previews).

Each step is also a target, and every write target has a read-only twin:

```sh
make store-setup-diff    make listing-dump    make listing-diff    make screenshots-dump    make screenshots-diff
make beta                # promote the build to the public TestFlight beta; re-run until Apple finishes processing
```

- Every tool stops with an error, before any write, if the app found for bundle ID `blue.luci.Muninn` is not id 6759760573.
- `listing/metadata.json` was seeded from the public listing (name and description only). On the build box run `make listing-diff`
  first to see what App Store Connect holds, and fill in the missing fields before any `listing-apply`.
- `make listing-check` and `make test-listing` run offline on any machine, with no credentials.
- **App Review contact:** set `REVIEW_CONTACT_FIRST_NAME`, `REVIEW_CONTACT_LAST_NAME`, `REVIEW_CONTACT_PHONE` and `REVIEW_CONTACT_EMAIL` in
  the build box's `~/.zshenv`, next to the API key. They never live in the repo.
- **Only the web UI:** the privacy "nutrition label" and the public TestFlight group named "Public Beta".
- This tooling has been tested offline only, so on the first run use the read-only `-diff` targets before the `-apply` ones.
