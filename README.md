# ⚓ Build Your Ship

A Roblox sailing, trading and shipbuilding game. Farm materials on the islands,
craft ship parts, build a real-looking vessel block by block in your own
drydock, haul physical cargo crates between island traders — and survive
pirates, storms and rival captains along the way. Bring friends as crew.

The look is realistic with an illustrated edge: Future lighting, real
materials (planks, fabric sails, iron, plaster, clay roof tiles), natural
colour grading, tapered hulls, billowing sails and subtle ink outlines.

## The guided path

New players get a welcome card, then a quest tracker (top right) with a
glowing waypoint walks them through the whole loop:

1. Chop wood → craft planks → craft hull blocks
2. Open the drydock (`B` next to your ship) and lengthen your ship
3. Launch (the vessel check must pass)
4. Buy a crate of fish, carry it aboard and stow it
5. Take the helm (`H`), sail to Ironrock, carry the crate to the trader and sell it
6. Mine iron, craft a cannon, mount it, sink a pirate ship (`F` broadside)
7. Invite a friend to your crew, then earn 2,000 gold trading

All quests live in `src/shared/Quests.luau`.

## Systems

### Sea zones and eras
The sea is split into rings around Port Haven. Each needs a better ship, so
progressing means redesigning:

| Zone | Era | Your ship needs |
| --- | --- | --- |
| Sheltered Bay (start) | Rowing | anything seaworthy (you start with a rowing boat) |
| Open Sea | Sailing | a sail, a keel, 10+ waterline hull, 7+ long |
| Far Reaches | Steam | an engine, 4 iron/steel waterline plates, 2 keels, 16+ hull, 9+ long |

A ship that isn't rated for a zone is pushed back by the rough water (and told
what's missing). Rougher zones have bigger waves, storms and pirates (ironclads
in the Far Reaches). Modern parts unlock as you **discover islands**:
Palm Cove teaches sailing, Ironrock / Spice Atoll teach steam and iron,
Frostpeak / Cinder Isle unlock diesel motors and steel hulls.

### Villages, safe zones, ramming and sound
- Every island has a village in its own style (harbour plaster, tropical stilt
  huts, stone cottages, snowy log cabins, basalt houses), a plaza with a well,
  walking villagers and a local shipwright who sells parts.
- The waters around every island (and Port Haven's harbour) are safe zones.
- Hitting another ship at speed rams it; hitting land runs you aground. The
  **Ram** bow deals triple damage and protects you.
- Sounds for cannons, explosions, splashes, crashes, thunder and rowing; slots
  for ambience and music in `src/shared/SoundIds.luau`.

### Building: the virtual drydock
- There are **no fixed berths**. Ships moor at any free spot in Port Haven's
  harbour (computed at runtime), so the world never needs changing for more players.
- Pressing `B` near your ship moves it into a **private drydock generated on
  demand** far from the ocean (`Config.DRYDOCK_ORIGIN`, one slot per builder).
  A dock clerk there sells parts. Pressing `B` again launches the ship back
  into the harbour.
- Build controls: click to place, `R` rotate, `X` delete mode, `1-9` select.

### Ships must look like ships
Placement rules (`ShipGrid.CanPlace`): keels only under the hull, deck
equipment (sails, cannons, holds, helm...) only on top of something, nothing
else below the waterline. A live **seaworthiness check** (`ShipGrid.VesselCheck`)
must be all green to launch:

- has a helm and a sail or engine
- waterline hull of 6+ blocks
- the front row is all **Bow** blocks, with one in the centre
- longer than wide (+2)
- at least 80% left/right symmetric

Bows taper automatically depending on which side of the centre line they sit,
so a row of three forms a pointed prow with a bowsprit.

### Physical cargo
- Every trade good is a **crate**. Buying one puts it on the trader's loading pad.
- Pick it up (`E`), walk it aboard (you walk slower) and stow it in a **Cargo
  Crate** block (2 crates each). The hull's float limits how much you can load.
- To sell, take a crate out of the hold and carry it to a trader. `G` drops a
  crate; dropped crates float in water.
- When a ship sinks, its crates spill into the sea for anyone to grab.

### Danger at sea (PvP on)
- Ships have hull HP (sum of their blocks). Iron hull is the armour.
- **Cannons**: crew can fire any cannon (`E`), or press `F` for a broadside on
  the side your camera looks at (camera pitch sets the range). Uses Cannonballs.
- At 0 HP the ship sinks; player ships are rebuilt in Port Haven after a short delay.
- **Pirates** (NPC ships) patrol, hunt players and fight broadside-to-broadside.
  Sinking one pays a bounty split by damage dealt, and spills loot.
- **Storms** roam the open sea: rain, fog, lightning, bigger swell, wind
  pushing the ship, and heavily loaded ships take on water. Keels help.
- Port Haven's harbour (ringed by buoys) is a **safe zone**: no damage, free repairs.
  Repair Kits patch the hull at sea.

### Crew / co-op
Captains invite players from the Crew panel (`C`). Crew members can board the
captain's ship (`H`), carry and stow cargo and man cannons. Gold from selling
the crew's crates is **split equally** between all crew members online.

### Gamepasses
Defined in `Config.GAMEPASSES` (shown in the in-game Store):

| Pass | Effect |
| --- | --- |
| 🏗️ Grand Shipyard | build frame 11 × 23 × 9 instead of 7 × 15 × 7 |
| 💰 Merchant Guild | +25% gold from every crate you sell |
| 🔨 Shipwright's Friend | 25% off in the shop |

Create the passes on the Creator Dashboard and paste their IDs into
`src/shared/Config.luau`. Passes with `Id = 0` show as "coming soon".

## Islands & trade routes

| Island | Resources | Sells (cheap) | Wants (pays well) |
| --- | --- | --- | --- |
| 🏠 Port Haven (bay) | oak, palm, flax | 🐟 Fish, 🏺 Pottery | 🌶️ Spices, 🛠️ Tools, 🧣 Furs |
| 🏝️ Palm Cove (bay) | palms, flax, a little iron | 🍍 Fruit, ☕ Coffee | 🏺 Pottery, 🛠️ Tools, 🐟 Fish |
| ⛏️ Ironrock (open sea) | pines, iron ore | 🛠️ Tools | 🐟 Fish, 🍍 Fruit, ☕ Coffee |
| 🌶️ Spice Atoll (open sea) | palms, flax | 🌶️ Spices | 🐟 Fish, 🛠️ Tools, 🏺 Pottery, 🧣 Furs |
| ❄️ Frostpeak (far reaches) | snowy pines, iron ore | 🧣 Furs | 🌶️ Spices, ☕ Coffee, 🍍 Fruit, 🛢️ Oil |
| 🌋 Cinder Isle (far reaches) | iron ore | 🛢️ Lamp Oil | 🧣 Furs, 🛠️ Tools, 🌶️ Spices, 🐟 Fish |

## Running it

The project uses [Rojo](https://rojo.space). The whole world (ocean, islands,
piers, NPCs, lighting) is generated by code at server start, so no `.rbxl` is needed.

```bash
rokit install        # or install Rojo 7.4+ manually
rojo serve           # then click "Connect" in the Rojo Studio plugin
# or build a place file:
rojo build -o BuildYourShip.rbxl
```

In Studio:

- Press **Play**. World generation takes a few seconds.
- To save progress, publish the place and enable
  *Game Settings → Security → Enable Studio Access to API Services*.
- `Lighting.Technology` is set to **Future** by the project file.
- Custom shapes are generated from parts in code (`BlockFactory`, `WorldBuilder`);
  no uploaded meshes or images are required.

## Project layout

```
src/
  shared/                 ReplicatedStorage.Shared
    Config.luau           tuning values, gamepasses
    Items.luau            resources, materials, tools, ship blocks
    Goods.luau            trade goods (one unit = one crate)
    Islands.luau          islands, markets, docks, safe harbour
    Quests.luau           the guided quest line
    Zones.luau            sea zones and their ship requirements
    SoundIds.luau         every sound id (paste Creator Store ids here)
    ShipGrid.luau         grid math, placement rules, vessel check
    ShipStats.luau        speed / float / crates / HP from a blueprint
    BlockFactory.luau     procedural models for every block and crate
    Remotes.luau          all RemoteEvents / RemoteFunctions
  server/Services/
    WorldBuilder          lighting, terrain, islands, props, NPCs, piers, drydocks
    ShipService           ships, harbour moorings, drydock, sailing, damage, sinking
    CargoService          crates: pads, carrying, stowing, spilling
    CombatService         cannons, cannonball simulation, effects
    PirateService         NPC pirate AI and bounties
    StormService          roaming storms
    CrewService           crews and invitations
    QuestService          quest progress and rewards
    GamepassService       pass ownership and purchases
    MarketService         island prices, buying and selling crates
    CraftingService       crafting and the shop
    HarvestService        trees / bushes / ore
    DataService / InventoryService / StateService
  client/
    UI/                   UIKit, HUD, Inventory, Shop, Market, Crew, Store, Tutorial
    Controllers/          Build, Helm, Prompt, Combat, Quest, Weather, Sound, Zone,
                          Outline, Effects, Navigation
```
