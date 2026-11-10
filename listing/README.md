# App Store listing assets

`metadata.json` is the desired state of the listing text (name, subtitle, description, keywords, promotional text, URLs, copyright,
release type and App Review notes) plus the `appStoreId` (6759760573) the tools insist on; `app.json` is the app's one-time store
settings (category, age rating, content rights, price); `screenshots/<locale>/` is the desired screenshot set. They are pushed with
`make listing-apply` and `make screenshots-apply`, or all of it with `make release` (build box only; see `DISTRIBUTION.md`). A field
the file doesn't mention is never touched. `app.json` says nothing about availability, so where the app is sold never changes. The
review contact comes from the build box's environment, not from this folder.

## Text

`metadata.json` was seeded from the public App Store listing, which only shows the name and description. The subtitle, keywords,
promotional text and URLs are not public, so they are left out: they are filled in from App Store Connect on the build box. Run
`make listing-diff` there to see what the store holds, copy those fields into `metadata.json`, and only then run `make listing-apply`.

Edit `metadata.json`, then `make listing-check` (offline) validates Apple's limits: 30 characters for the name and subtitle, 100 for
keywords, 170 for promotional text, 4000 for the description. Keywords carry no spaces after commas.

## Screenshots

`listing/screenshots/en-US/` holds the Mac App Store screenshots: 2880 × 1800 PNGs (16:10, one of the sizes the Mac App Store
accepts), in file-name order. They are **generated, not drawn**:

```sh
make screenshots
```

That builds a debug Muninn and runs it with `--screenshots`. The screenshot mode (`ScreenshotMode.swift`, `ScreenshotScenes.swift` and
`ScreenshotFixtures.swift`, compiled in debug builds only, never in a release) renders the **real views** against made-up fixture
history and snippets, a frozen clock and a private UserDefaults suite. It never reads the real clipboard, history or preferences. Each
scene is laid out at 1280 × 800 points and drawn at 2.25x, with a caption on a cream-to-blue background that matches luci.blue.

Until the PNGs are rendered the folder holds only a `.gitkeep`, and `make listing-check` passes with a note that no screenshots exist yet.

To change a screenshot, edit the scene in `ScreenshotScenes.swift` (or the fixtures in `ScreenshotFixtures.swift`) and run
`make screenshots`; to add one, add a scene. Check the PNGs by eye before committing. Output is written to the sandbox container
(`~/Library/Containers/blue.luci.Muninn/Data/tmp/shots/`) and copied here by the make target.
