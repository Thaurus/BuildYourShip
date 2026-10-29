# CLAUDE.md

Guidance for Claude (and humans) working on **Build Your Ship**, a Roblox
sailing / trading / shipbuilding game written in Luau and synced with Rojo.
See `README.md` for the player-facing design.

## Standing rule: keep the status lists current

**Every time you change this project, update the two lists at the bottom of
this file** ("What is missing" and "What is not working / known issues"):

- Add anything you notice is missing, broken, risky or unverified.
- Remove or tick off items you fix, in the same commit as the fix.
- Be honest: if something was not tested in Roblox Studio, say so.
- Mention the status changes in your summary to the user.

## Project basics

- Sync with Rojo: `rojo serve` (Studio plugin) or `rojo build -o BuildYourShip.rbxl`.
- `src/shared` → `ReplicatedStorage.Shared`, `src/server` → `ServerScriptService.Server`,
  `src/client` → `StarterPlayer.StarterPlayerScripts.Client`.
- The whole world is generated in code at server start (`WorldBuilder`);
  there is no place file to keep in sync.
- No Luau toolchain (luau-analyze, selene, StyLua) is installed in the cloud
  session. Code can't be run or type-checked here, so be extra careful and say
  so when reporting.

## Architecture

- **Server services** live in `src/server/Services`. Each exports optional
  `Init(services)` (store references, no side effects) and `Start()`.
  `Main.server.luau` requires all of them, calls every `Init`, builds the world,
  then calls `Start` in `START_ORDER`. Newer services keep a single `S` table of
  all services; call other services as `S.ShipService.X(...)`.
- **Shared rules** (`ShipGrid`, `ShipStats`, `Items`, `Quests`, ...) are used by
  both server (validation) and client (previews, UI). Change rules there only,
  so both sides agree.
- **Networking** lives only in `src/shared/Remotes.luau`. Add new remotes to
  the `EVENTS` / `FUNCTIONS` lists. RemoteFunctions return `{ ok, msg }`;
  the client's `ctx.Invoke` shows `msg` as a toast.
- **Client state**: the server pushes one snapshot per player through
  `StateService.Push(player)` (coalesced per frame). The client reads it via
  `ClientState.Observe` / `ClientState.Changed`. After changing anything a
  player sees, call `StateService.Push`.
- **Server is authoritative**: validate every remote argument (types, NaN,
  integers, ranges, distance to NPCs/ships, ownership/crew).
- **Prompts** that depend on carrying a crate use the `FilteredPrompt` tag plus a
  `Need` attribute ("Crate"/"Empty"); the server locks them with the `Locked`
  attribute, never by toggling `Enabled`.
- **Model pivots don't follow physics.** For blocks on a ship use
  `ShipService.CellCFrame(ship, key)` or attachments, not `block:GetPivot()`.
- Ships: `ship.Captain` is a Player for player ships and nil for pirates
  (`ship.IsNPC`). The ship a player sails on is `ShipService.ShipFor(player)`
  (their captain's when in a crew).

## Conventions

- Tabs, ~120 columns, double quotes, `stylua.toml` style.
- Match the existing comment density: a short header comment per module,
  brief comments for non-obvious logic.
- Tunables go in `src/shared/Config.luau`; colours in `Palette.luau`;
  UI colours/fonts in `src/client/UI/UIKit.luau`.
- Don't add uploaded asset IDs without telling the user; everything visual is
  currently built from parts and Roblox materials.

---

## What is missing

Features not built yet (roughly by priority):

- [ ] **Playtest pass in Roblox Studio** – nothing has been run yet (see known issues).
- [ ] **Mobile / gamepad controls** for build mode (rotate, delete, select), broadside (F),
      drop crate (G) and the I/B/H/C hotkeys. Only on-screen HUD buttons work on touch.
- [ ] **Audio**: cannon shots, explosions, splashes, thunder, waves, music, UI sounds
      beyond the two built-in pings.
- [ ] **Gamepass IDs**: `Config.GAMEPASSES` all have `Id = 0` ("coming soon") until the
      passes are created on the Creator Dashboard.
- [ ] Delivery contracts / timed jobs from traders.
- [ ] Ramming damage and collision damage with rocks/islands.
- [ ] Ship customisation: names, hull paint, sail colours (good for cosmetics).
- [ ] Gangway in the drydock (players reach the deck only via "Board" teleport).
- [ ] Safe zones at other islands' trading posts (currently only Port Haven is safe).
- [ ] More pirate variety (sizes, a boss ship), pirate NPC figures on deck.
- [ ] Leaderboards beyond leaderstats Gold (richest captain, pirates sunk).
- [ ] Localisation (e.g. German), developer products, analytics.
- [ ] Custom meshes/textures (optional; procedural parts are used now).

## What is not working / known issues

Nothing below has been confirmed in Studio; these are risks or known gaps.

- [ ] **Untested**: the whole codebase has never been run or type-checked. Expect
      runtime errors on first play; fix them and update this list.
- [ ] Ship physics tuning (LinearVelocity / AlignPosition / AlignOrientation forces,
      float height, turn rates) is unverified; ships may jitter, sink into or bounce off terrain.
- [ ] Captains own their ship's network physics, so an exploiter could teleport their
      ship. Server only validates actions, not ship positions.
- [ ] No DataStore session locking: joining two servers at once could overwrite saves.
- [ ] Ship HP is not saved; it resets to full on rejoin. Carried crates are dropped
      (lost) when a player leaves.
- [ ] Pirate AI is simple steering without pathfinding; pirates can get stuck on
      islands or shallow terrain.
- [ ] Storm "lightning" is only a brightness flash; there is no sound and the rain
      uses a generic sparkle texture.
- [ ] Highlight outlines are capped (28 nearest models); very large models (drydock,
      pier) may outline oddly.
- [ ] Emoji icons rely on the platform's emoji font and may look different per device.
- [ ] If the harbour runs out of free mooring spots, ships are placed at random
      further out to sea (may overlap).
- [ ] `rokit.toml` pins Rojo 7.4.4; adjust if that version isn't available.
