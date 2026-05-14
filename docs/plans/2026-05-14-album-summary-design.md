# Album Summary Entry Design

## Goal

RePhoto should open to a time-based album summary instead of immediately showing a single media item. The summary gives users a quick way to choose a time window, then opens the existing gesture-based browser scoped to that window.

## Confirmed Decisions

- The summary excludes media currently in trash.
- The app should use a full route split for future expansion:
  - `AlbumSummaryPage` is the app entry experience.
  - `MediaBrowserPage` owns media browsing, gestures, current media preview, thumbnails, and bottom actions.
- Time summary entries include fixed recent windows and monthly buckets.
- Selecting an entry opens the browser at the first media item captured in that time range.
- The browser keeps the existing random/sequential control.
- The browser adds a lazily built horizontal thumbnail strip for all media in the active condition.

## Architecture

### Album Summary Page

`AlbumSummaryPage` owns the top-level library view. It receives the shared controller and presents:

- Recent windows:
  - `近三天`
  - `近一周`
- Monthly buckets, newest month first:
  - Example: `2026年4月`

Each row displays:

- Photo count
- Video count
- Known total size

Rows with no media are hidden. All counts exclude trashed media. Tapping a row pushes `MediaBrowserPage` with a `MediaCollectionQuery`.

### Media Browser Page

`MediaBrowserPage` is the current browsing experience after extracting it from `HomePage`. It receives:

- The shared `HomeController`
- A collection query containing title, time range, and initial ordering

When opened, the controller applies the query and starts from the first matching media item by capture time. After that, existing gestures and random/sequential behavior remain available.

The page includes:

- Existing media preview card
- Existing gesture handling
- Existing trash/settings/share/import behavior where appropriate
- Existing random/sequential and video-only bottom buttons
- A new thumbnail strip above the bottom action buttons

### Query Model

Add a lightweight model for browser entry:

- `MediaCollectionQuery`
  - `title`
  - `timeStart`
  - `timeEnd`

The model can later grow to support location, device, favorites, search, tags, or custom smart albums without changing the browser page contract.

### Summary Model

Add a summary model:

- `AlbumSummaryEntry`
  - `id`
  - `title`
  - `timeStart`
  - `timeEnd`
  - `photoCount`
  - `videoCount`
  - `knownSizeBytes`
  - `hasUnknownSize`

The controller builds these entries from the current media collection and trash state.

### Media Size

Add `sizeBytes` to `MediaItem`.

- macOS folder imports can read file size directly.
- Mobile media loading should fill size when the platform metadata can provide it.
- If a size is unavailable, it remains null and the summary shows known size with an unknown marker.

## Data Flow

1. App boots and loads media into the shared controller.
2. `AlbumSummaryPage` reads `controller.albumSummaryEntries`.
3. The controller groups non-trashed media by recent windows and by month.
4. User taps an entry.
5. `AlbumSummaryPage` pushes `MediaBrowserPage`.
6. `MediaBrowserPage` applies the entry query and starts at the first matching media item.
7. Browser deletes/restores/permanently removes media through the shared controller.
8. Returning to summary rebuilds counts from the updated controller state.

## Thumbnail Strip

The thumbnail strip uses the browser query's current filtered media ids.

- Use `ListView.builder` for horizontal lazy construction.
- Each item uses a small `MediaThumbnailTile`.
- Photo thumbnails reuse existing preview byte/file loading behavior.
- Video thumbnails reuse preview bytes when available and overlay a play icon.
- The current media is highlighted.
- Tapping a thumbnail jumps to that media and updates controller browsing history.

## Error Handling

- If permission is not granted, the summary page shows the existing library status message.
- If a summary entry becomes empty before navigation, tapping it does nothing.
- If no media exists outside trash, the summary page shows an empty state.
- Unknown file sizes do not block grouping or navigation.

## Testing

Add controller tests for:

- Recent window summaries exclude trashed media.
- Monthly summaries include photo/video counts and size.
- Applying a query starts from the first media item in chronological order.
- Thumbnail jumping updates the current media.

Add widget tests for:

- App starts on album summary.
- Tapping a month opens the browser.
- Browser shows a lazy thumbnail list and keeps bottom actions.
