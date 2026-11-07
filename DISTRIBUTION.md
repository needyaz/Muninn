# Distribution

Muninn is distributed as a **Developer ID-signed, notarized** build attached to a GitHub Release. This is the author's release process;
you don't need any of it to build or run Muninn (see the README).

```sh
make github-release
```

`scripts/direct_release.sh` then: archives in Release with the stamped version, exports with the Developer ID method, notarizes with
`notarytool` (waiting for Apple's verdict), staples the ticket, checks it with Gatekeeper's own assessment, zips it, and runs
`gh release create` for the tag `v<VERSION>` (or uploads over an existing release for that tag). The binary is never committed.

The marketing version is `1.0.<commit count>` and the build number is the commit count, so a release always matches a commit.
`make github-release` refuses a dirty working tree for that reason; push before you release.

## One-time setup

- A **Developer ID Application** certificate for your team (Xcode > Settings > Accounts > Manage Certificates, or developer.apple.com).
- `TEAM` (and `BUNDLE_ID`) in `make/local.mk`; see `make/local.mk.example`.
- Notarization credentials, either:
  - a keychain profile: `xcrun notarytool store-credentials muninn-notary`, then `export NOTARY_PROFILE=muninn-notary`; or
  - an App Store Connect API key: `ASC_KEY_ID`, `ASC_ISSUER_ID` and `ASC_KEY_FILEPATH` in your environment.
- The `gh` CLI, signed in (`gh auth login`), and `xcodegen` (`brew install xcodegen`).

## Notes

- This build has no updater: the release notes tell people to download a newer release.
- Untested until the first run.
