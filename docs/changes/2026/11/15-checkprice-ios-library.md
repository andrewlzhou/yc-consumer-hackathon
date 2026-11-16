# 2026-11-15 Check Price iPhone: Threads becomes Library

- Author: Claude (Opus agent), for Andrew.
- Instructions: owner: rows like Shazam's with a picture on the left; title the page "Library"; Watchlist filters the list in place instead of opening a page; remove favourites; give a way to save an item. Saved in `ios/AGENTS.md` (no-titles exceptions, Threads entry).
- Changed: "Library" title in the content. The Watchlist row toggles a saved-only filter (bookmark fills orange when on); the "Recents" label stays either way. Rows: a 56pt rounded tile, name over retailer, and a bookmark button on the right (orange filled when saved); swipe left and long-press also save. The pushed Watchlist/Hearted screen and the filter file are gone.
- Picture: no product image exists in `Product`, ShopperKit's contract, or Convex on `origin/main` / `origin/ruhaan_backend` (only raw store-page fixtures), so the tile shows the product's SF symbol on a grey fill.
- Hearts removed app-wide: Hearted row, heart swipe and menu item, the detail's heart button, `isHearted`/`hearted`/`toggleHeart`, and Account's Hearted shelf and its tab picker (Account shows only the saved grid).
- Checks: `scripts/typecheck.sh` passed (app and widget), `check_docs.py` passed. No full Xcode here; the Revyl build is the first real build.
