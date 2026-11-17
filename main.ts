// Brainrot Bay: the entrypoint for roblox-brainrot-01 (Node 22, standard
// library only). It hands the game in: it copies game.rbxl, src/,
// screenshots/ and PLAY.json from beside this file to /output and writes
// /output/dossier.json, the summary the judge reads, with the vendored
// make.fun library (vendor/makefun-roblox.ts, the kit's copy, unchanged).
//
// The game is a Rojo project: `rojo build default.project.json --output
// game.rbxl` rebuilds the place from src/ and default.project.json.
// Screenshots live in screenshots/ (the first by name is the cover, and
// one of them is the thumbnail uploaded for the game on Roblox).
// PLAY.json names the published place; until the place is published its
// ids are 0 and the gate refuses the entry, so fill it in after the
// publish step in Studio and rebuild.
//
// Every name under /output starts with a letter, a digit or _ and holds
// only letters, digits, . _ and -: the grader fails an entry whose output
// holds any other, so a file such as .gitkeep or .DS_Store copied in
// fails it. src/ and screenshots/ are copied without any name that
// starts with a dot, at any depth.
//
// Outside the grader's container, MAKEFUN_OUTPUT_DIR stands in for /output:
//   mkdir -p out && MAKEFUN_OUTPUT_DIR=out node main.ts

import { copyFileSync, cpSync, existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildDossier } from './vendor/makefun-roblox.ts';

const here = fileURLToPath(new URL('.', import.meta.url));
const out = process.env.MAKEFUN_OUTPUT_DIR ?? '/output';

/** cpSync's filter: leave out every file and directory whose name starts with a dot (.gitkeep, .DS_Store, .git). */
function notDotted(path: string): boolean {
	return !basename(path).startsWith('.');
}

// The place, the play link and the sources, in that order.
copyFileSync(join(here, 'game.rbxl'), join(out, 'game.rbxl'));
copyFileSync(join(here, 'PLAY.json'), join(out, 'PLAY.json'));
cpSync(join(here, 'src'), join(out, 'src'), { recursive: true, filter: notDotted });
mkdirSync(join(out, 'screenshots'), { recursive: true });
if (existsSync(join(here, 'screenshots'))) {
	cpSync(join(here, 'screenshots'), join(out, 'screenshots'), { recursive: true, filter: notDotted });
}

// A quick sanity read so a broken PLAY.json fails here, loudly,
// instead of silently handing the grader a bad link file.
const play = JSON.parse(readFileSync(join(here, 'PLAY.json'), 'utf8')) as { place_id?: unknown; universe_id?: unknown };
if (typeof play.place_id !== 'number' || typeof play.universe_id !== 'number') {
	throw new Error('PLAY.json must hold numeric place_id and universe_id');
}
if (play.place_id === 0 || play.universe_id === 0) {
	console.warn('WARNING: PLAY.json still names no published place (ids are 0). Publish the place from Roblox Studio and fill it in before submitting, or the gate refuses the entry.');
}

// The scorer's own caps (reference/gate.json): only text_max_bytes shapes
// the bytes; the others refuse an entry the scorer would refuse (more than
// 4 screenshots or one over 256 KiB; a place of more than 500000 instances,
// whose scripts' sources come to over 8 MiB or whose scripts' paths come
// to over 1048576 characters, in all).
writeFileSync(
	join(out, 'dossier.json'),
	buildDossier(out, {
		text_max_bytes: 65536,
		screenshots: { max: 4, max_bytes: 262144 },
		max_instances: 500000,
		scripts_max_source_bytes: 8388608,
		scripts_max_path_chars: 1048576,
	}),
);

console.log(`Brainrot Bay handed in: place ${play.place_id}, universe ${play.universe_id}.`);
