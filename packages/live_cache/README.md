# live_cache

Temporary-resource cache for Pure Live.

The package owns one clearable tree — images, temporary files and a light
JSON index — and nothing else. Downloads, recordings, favourites and user
wallpapers are persistent data and never enter it.

## Shape

- **Policies** — every image names a category; the preset policies decide
  the TTL, priority, expiry mode and memory behaviour. Business modules pass
  a policy, never a folder or a file name.
- **Key** — an explicit business key wins, then the URL, each combined with
  the policy version and an optional account scope and hashed with SHA-256.
  Signed query strings therefore do not create a new file unless the caller
  asks for one.
- **Disk** — bytes are written through a temporary `.part` file, validated
  by their format magic and renamed into place. The JSON index beside the
  files is flushed with a debounce and rebuilt by scanning when lost.
- **Memory** — decoded images stay in Flutter's own `ImageCache`; this
  package only evicts them by category so it does not hold a second copy of
  the encoded bytes.
- **Refresh** — policy modes: `staleWhileRevalidate` draws the stale copy
  and refreshes in the background, `refreshBeforeDisplay` fetches first and
  falls back to the stale copy on failure, `cacheOnly` never opens a
  connection.
- **Cleanup** — TTL, then priority and least-recent access, until the
  configured cap is met. `permanent` entries are only removed by an explicit
  clear or a capacity emergency.

## Boundaries

`live_cache` does not create global singletons and does not read settings.
The host application passes the cache directory, the HTTP client, the
configuration and the policies; the manager's lifecycle belongs to the
composition root.
