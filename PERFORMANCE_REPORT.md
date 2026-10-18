# DifficultBulletinBoard: performance review

## Where the time went (ranked)

1. **The GUI redraw re-categorized every stored message, once per chat line.**
   Each accepted chat line triggered `UpdateMessages()` (Logs) plus `UpdateCategories()` on the active tab. Both called `CategorizeMessage` for every stored message (up to 100). Each call scans about 55 categories and about 200 tags, lowercases the message once per category, and re-checks each tag for wildcard characters. `GetCategorizedMessages` also did an O(n²) duplicate check that ran `StripHyperlinks` (3 gsubs) and `string.lower` on both sides of every comparison. In a busy World channel this ran several times per second while the window was open.
2. **Per-frame hover polling bug on every visible row.** `isHovered` starts as `false`, but `MouseIsOver()` returns `nil` when the mouse isn't over the row. The check `nil == false` is never true, so the "not hovered" branch (`SetText` + `SetTextColor` on the name) ran every frame for every visible row: 50 to 100+ rows at your full FPS. Each row also measured scroll-frame geometry (4× `GetTop/GetBottom` plus a parent walk) every frame.
3. **The chat-frame hook processed every line in every chat window, including the combat log.** Combat, spell and loot lines went through 3 gsubs, sender extraction, `pcall(ShouldHideFromChat)`, `UnitName`, and several lowercases and pattern finds before being rejected as "source not monitored". In a raid that is hundreds of lines per second and constant garbage, which causes GC hitches. Lines that show in several chat windows were also evaluated once per window, with full categorization each time.
4. **Wildcard patterns were recompiled on every match.** `ConvertWildcardToLua` builds the pattern one character at a time with string concatenation. It ran for every wildcard tag, filter tag (`LF*M`) and blacklist keyword (`recruit*`, `<*>`, `\[???\]`…) on every message.
5. **The same message was categorized up to 4 times per line.** This happened in `AddMessage` (full and base), in the chat hook, and in `RemovePreviousMessageFromSameSender`, which also re-categorized the sender's old messages.
6. **Smaller items:**
   - The Logs scroll `OnUpdate` called `IsShown()` 50 times and a full `UpdateScrollState()` on every frame.
   - Message truncation ran a `SetText/GetStringWidth` binary search (about 8 font measurements per row) on every redraw, even when nothing had changed.
   - The expiry sweep walked the whole list on every line.

## What was changed (behavior preserved)

| File | Change |
|---|---|
| `api/categories.lua` | `CategorizeMessage` results are memoized per (message, flags). The cache is invalidated by every mutating API (tags, selected, filter tags) and when config tables are replaced (resets). The lowercased message is reused across categories. Per-tag lowercase, length and wildcard flags are precomputed. Filter-tag info is cached. `DBB2.api.InvalidateCategoryCache()` is exposed for any future code that edits config tables directly. |
| `api/wildcards.lua` | Compiled Lua patterns are cached per wildcard. Lowercasing uses a one-entry memo. |
| `api/messages.lua` | GUI updates are coalesced: at most one redraw of the **active** tab every 0.2 s (`DBB2.api.RequestGuiRefresh`). Normalized duplicate keys are computed once per stored message (`GetMessageKeys`). The expiry check exits early when the oldest message is fresh. The unsorted-message scan is skipped when none exist. |
| `api/chat_filter.lua` | Fast path: non-filterable `CHAT_MSG_*` events (combat log, loot, system…) go straight to the original `AddMessage`. The same line rendered into several chat windows in the same frame reuses one decision. Both are disabled while the debug console is recording, so diagnostics are unchanged. |
| `api/gui_schema.lua` | Fixed the per-frame hover bug (boolean coercion). Geometry is only checked when the mouse is actually over a row. Truncation results are cached per (text, width). Anchors are only reset when the time display mode changes. |
| `modules/gui.lua` | The Logs scroll `OnUpdate` uses the row count from the last redraw and only updates scroll state when sizes change. |
| `DifficultBulletinBoard.lua`, `modules/version_check.lua` | New `DBB2.After(delay, fn)` helper. It uses ClassicAPI's `C_Timer.After`, with a tiny self-hiding fallback frame if the DLL is missing (a one-line notice is printed). It replaces two one-shot OnUpdate delay frames. |

## Verification

- **Old vs new categorization:** 3,000 generated LFG-style messages × 4 flag combinations, run on default config, after API mutations (filter tags on, category disabled, wildcard tags) and after a wholesale reset. **0 differences.** Filter-tag and blacklist wildcard results were also identical.
- **End-to-end:** 4,000 simulated chat lines through `ShouldHideFromChat` and `AddMessage` (duplicates, same-sender replacement, unsorted capture, all 3 hide modes). The stored list and **all 4,000 hide/show decisions matched** the original.
- **Micro-benchmark** (desktop Lua 5.3; the 1.12 client's Lua 5.0 is slower, so the absolute gains in game are larger):
  - Redraw-equivalent workload (100 stored messages × 50 redraws): **425 ms → 6 ms**.
  - New messages: **0.084 → 0.048 ms each**.
- Not tested in the game client. Please check in game: window open on Logs and Groups in a busy World channel, hover rows, tooltips on truncated messages, resize, the hide-from-chat modes, and a raid with the combat log open.

## Reverting

The addon folder is a git repo, so `git diff` shows every change and `git checkout -- .` restores the originals. `PERFORMANCE_CHANGES.patch` holds the same diff.

## Possible next steps (not done)

- Build the Groups/Professions views incrementally (bucket each message into its categories once at insert time) instead of rebuilding from scratch. This only matters if you raise `MAX_MESSAGES` well above 100.
- Use ClassicAPI's `table.wipe` to reuse the per-redraw tables in `UpdateCategories` and cut garbage further.
- With ClassicAPI's modern `OnEnter/OnLeave` you could drop hover polling entirely. The current polling exists to suppress tooltips on rows that are partly scrolled out of view.
