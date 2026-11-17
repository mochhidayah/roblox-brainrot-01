# Brainrot Bay — Steal a Brainrot, buy the belt, survive the tsunami

[![make.fun](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/mochhidayah/roblox-brainrot-01/rank.svg)](https://make.fun/bounty/roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/mochhidayah/roblox-brainrot-01/reward.svg)](https://make.fun/bounty/roblox-brainrot-01)

A 3D Roblox brainrot game for make.fun's ["Make the best AI Roblox brainrot game"](https://make.fun/bounty/roblox-brainrot-01) bounty (roblox-brainrot-01). Built by a coding agent in recorded sessions.

## The game

You spawn on Brainrot Bay, an island in the middle of the ocean. A conveyor belt along the north edge rolls out absurd meme-born characters — Pisang Panik, Kopi Kucing, Ayam Angkasa, Hiu Hologram, Gajah Gitar, Naga Nasi, Robot Roti, Raja Rujak, Dewa Durian, and the Secret Bayangan Bakso — each earning money every second. Click one on the belt (or in the shop panel) to buy it, and it walks to your base and starts paying you.

- **Climb the ladder**: Common → Rare → Epic → Legendary → Mythic → Secret, with Golden, Diamond, Rainbow and Cosmic mutations multiplying the rate up to 25x.
- **Steal**: walk up to a rival's base and grab their brainrot — then dash home carrying it over your head, slower than usual, while they chase you. Lock your base ($250, 30 seconds) to stop thieves cold.
- **Survive the tsunami**: every two minutes a wall of water sweeps the island north to south. Caught off your base, you drop what you carry and get knocked back to spawn. Ten seconds of warning — use them.
- **Golden Hour** doubles income for a minute; **Mutation Surge** makes rare mutations far more likely.
- **Rebirth**: hand back your brainrots and most of your cash for +50% income forever — and a gold crown.

## Play it

The published place is linked in [PLAY.json](PLAY.json). To publish it yourself from Roblox Studio: open `game.rbxl`, **File → Publish to Roblox**, pick **Create New Experience**, then on the Creator Dashboard set the experience **Public**, put your make.fun play code in its description, and upload `screenshots/1-cover.jpg` as its first thumbnail and a 512×512 icon. (Publishing needs the owner's Roblox account — see `PLAY.json` for the place and universe ids once published.)

## Build it

A Rojo project. The place is built from `src/` and `default.project.json`:

```sh
rojo build default.project.json --output game.rbxl
```

Screenshots live in `screenshots/` (the first by name, `1-cover.jpg`, is the cover and the game's first thumbnail on Roblox). The entrypoint hands the game in as the grader does:

```sh
mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts
```

## Layout

- `main.ts` (Node 22, standard library only) — copies `game.rbxl`, `src/`, `screenshots/` and `PLAY.json` to `/output` and writes `/output/dossier.json` with `vendor/makefun-roblox.ts` (the kit's copy, unchanged).
- `src/shared/` — `Config.luau` (every tuning number) and `BrainrotData.luau` (the cast, rarities, mutations).
- `src/server/` — `init.server.luau` (bootstrap + remotes), `WorldBuilder.luau` (the 3D world and every character model), `GameState.luau` (one place for all player state), `Economy.luau` (income, buying, selling, rebirth), `Conveyor.luau` (the belt), `StealSystem.luau` (stealing and carrying), `EventSystem.luau` (tsunami, Golden Hour, Mutation Surge).
- `src/client/` — `Game.client.luau` (HUD: top bar, shop, base, rivals, actions) and `Effects.client.luau` (screen shake, flashes, floating `+$X`).
- `TOUR.json` — the optional tour: which keys bring the game to each screenshot.

## License

MIT — see [LICENSE](LICENSE).
