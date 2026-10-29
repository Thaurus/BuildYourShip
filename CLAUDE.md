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
- No Luau toolchain is installed in the cloud session, and the user can't always
  run Studio. **GitHub Actions is the check**: `.github/workflows/check.yml` runs on
  every push: `rojo build` (uploads `BuildYourShip.rbxl` as an artifact), `selene src`
  (warnings fail the build) and `luau-lsp analyze` against the Roblox API types.
  After pushing, read the run's logs and keep it green. Tool versions: `aftman.toml`
  (luau-lsp is fetched as the latest release).
- Passing CI only proves syntax, lint and types are fine. It does **not** run the
  game, so physics, gameplay and visuals are still untested until a Studio playtest.

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
- **Zones & eras** (`Shared/Zones.luau`): rings around Port Haven. A ship's rating
  (`Zones.Rating(blueprint)`) is the furthest zone it qualifies for; `ShipService`
  pushes ships out of zones above their rating. Items have a `Tier`; players unlock
  tiers by mooring at islands (`Islands.<id>.Unlocks`, `QuestService.Discover`).
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
- [ ] **Custom audio**: `src/shared/SoundIds.luau` has empty slots for ocean and wind
      ambience and music per zone/drydock. Cannon, explosion and thunder use Roblox's built-in
      Explosion sound; splash, crash, rowing and UI use built-in `rbxasset://sounds/...` files.
      Paste Creator Store audio ids for proper cannon, wave, crash and music sounds.
- [ ] **Mobile / gamepad controls** for build mode (rotate, delete, select), broadside (F),
      drop crate (G) and the I/B/H/C hotkeys. Only on-screen HUD buttons work on touch.
- [ ] **Gamepass IDs**: `Config.GAMEPASSES` all have `Id = 0` ("coming soon") until the
      passes are created on the Creator Dashboard.
- [ ] Oars don't animate while rowing (only a splash sound plays).
- [ ] Villagers only walk between fixed points (no pathfinding, no animations, no dialogue).
- [ ] No reward/content for the 4th era yet beyond Diesel Motor and Steel Hull
      (no 4th zone; Tier 4 parts are just stronger).
- [ ] Delivery contracts / timed jobs from traders.
- [ ] Ship customisation: names, hull paint, sail colours (good for cosmetics).
- [ ] Gangway in the drydock (players reach the deck only via "Board" teleport).
- [ ] More pirate variety (a boss ship), pirate NPC figures on deck.
- [ ] Leaderboards beyond leaderstats Gold (richest captain, pirates sunk, furthest zone).
- [ ] Localisation (e.g. German), developer products, analytics.
- [ ] Custom meshes/textures (optional; procedural parts are used now).

Done recently: sound system, ramming / running aground, safe zones at every island,
villages on every island, sea zones with rowing → sailing → steam eras and tier unlocks.

## What is not working / known issues

Nothing below has been confirmed in Studio; these are risks or known gaps.

- [ ] **Never run**: the game has never been started in Studio. CI (build, selene,
      luau-lsp) passes, so syntax and types are OK, but runtime errors, wrong
      Roblox property values and gameplay bugs are still likely on first play.
- [ ] Type checking runs in non-strict mode for most files, so it won't catch every
      nil/field mistake.
- [ ] `Player:LoadCharacterAsync` is used because the type checker marked `LoadCharacter`
      deprecated; behaviour should be identical but is unverified.
- [ ] Ship physics tuning (LinearVelocity / AlignPosition / AlignOrientation forces,
      float height, turn rates) is unverified; ships may jitter, sink into or bounce off terrain.
- [ ] Ramming is detected from a sudden speed drop plus a box query in front of the bow.
      Side or stern collisions only count as "ran aground", and the thresholds
      (`Config.RAM_*`) are untuned; false positives are possible.
- [ ] The built-in Explosion sound is assumed to play even with `Visible = false`; if it
      doesn't, cannons and thunder are silent until custom ids are set.
- [ ] The `rbxasset://sounds/...` paths in `SoundIds` are believed to ship with the client
      but haven't been verified.
- [ ] Zone push-back is a velocity nudge; very fast ships may poke past the border briefly.
- [ ] Village houses are skipped where the ground isn't flat, so rocky islands
      (Ironrock, Cinder Isle) may get fewer houses than intended.
- [ ] Captains own their ship's network physics, so an exploiter could teleport their
      ship (or out of a zone). Server only validates actions, not ship positions.
- [ ] No DataStore session locking: joining two servers at once could overwrite saves.
      The store was renamed to `BuildYourShip_v3`, so earlier test saves are gone.
- [ ] Ship HP is not saved; it resets to full on rejoin. Carried crates are dropped
      (lost) when a player leaves.
- [ ] Pirate AI is simple steering without pathfinding; pirates can get stuck on
      islands or shallow terrain.
- [ ] Storm rain uses a generic sparkle texture.
- [ ] Highlight outlines are capped (28 nearest models); very large models (drydock,
      pier) may outline oddly.
- [ ] Emoji icons rely on the platform's emoji font and may look different per device.
- [ ] If the harbour runs out of free mooring spots, ships are placed at random
      further out to sea (may overlap).
- [ ] `rokit.toml` pins Rojo 7.4.4; adjust if that version isn't available.
