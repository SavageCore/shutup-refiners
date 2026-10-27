# Shut Up Refiners

Mutes all the **refiners** in No Man's Sky. Built natively on Linux with the
[AMUMSS Linux port](https://github.com/SavageCore/AMUMSS/tree/feat/linux-support).

## Usage

Install it and pick which refiners to mute.

| Option | What it mutes | Files patched |
| --- | --- | --- |
| `Refiners` | The small, medium and large refiner you place on a planet | 3 |
| `Refiners and Personal Refiner` | Those, plus the Personal Refiner in your Exosuit inventory | 4 |

| Refiner | Entity MBIN | Sounds muted |
| --- | --- | --- |
| Small / Portable | `REFINER1.ENTITY.MBIN` | 2 |
| Medium | `REFINER2.ENTITY.MBIN` | 2 |
| Large | `REFINER3.ENTITY.MBIN` | 2 |
| Exosuit | `PLAYERCHARACTER.ENTITY.MBIN` | 2 |

The small refiner and the Personal Refiner keep their out-of-fuel cue. Both
have a `REFINE_NOFUEL` state that posts the same sound as the normal
end-of-cycle, so the two can only be told apart by state, and the running-dry
one is deliberately left alone.

## Compatibility

Modifies the refiner entity files under
`MODELS/PLANETS/BIOMES/COMMON/BUILDINGS/PARTS/BUILDABLEPARTS/TECH/REFINER/ENTITIES/`
and, for the `Refiners and Personal Refiner` option, the player character
entity under `MODELS/COMMON/PLAYER/PLAYERCHARACTER/PLAYERCHARACTER/ENTITIES/`.
Nothing else.

The generated patches are minimal: two `Sound` values per file and nothing
else, so load-order conflicts with unrelated mods should be rare. The player
character entity is a large shared file, so a mod that rewrites it will
conflict outright.

**These files live in `NMSARC.Precache.pak`, not a normal data pak.**

## Build (on Linux)

Requires a full AMUMSS install at `~/AMUMSS` (override with
`AMUMSS_HOME=...`) with `MBINCompiler-linux` fetched
(`linux/scripts/fetch_mbincompiler.sh` in the AMUMSS repo).

```sh
make release      # clean rebuild + verify + pack dist/ zip (default)
make verify       # sanity-check the built outputs
make clean        # remove build/ and dist/
```

`make build` clears this mod's folders out of
`$(AMUMSS_HOME)/CreatedMODS`, temporarily stages the variant scripts into
`$(AMUMSS_HOME)/ModScript` (existing content moved aside and restored), runs one
`buildmod.sh --run-pipeline`, and collects the outputs.

### `make verify` is the load-bearing step

It asserts, per variant and per file, that the EXML was produced by *this* run,
that the expected number of `Sound` values were rewritten to `INVALID_EVENT`,
that none of the original event names survived, that the refiner states which
should be muted are in the patch, that the state which should be kept is not,
and that there are no marker tags.

The count check exists because of how AMUMSS fails: a `SPECIAL_KEY_WORDS` path
that stops matching does not error, it silently applies the change to whatever
it can still reach and ships that.

The state checks exist because the running-dry cue shares its event name with
the normal end-of-cycle one. Only the state name separates them, so a patch
that has quietly drifted onto the wrong state takes a sound the player asked to
keep, and the count alone would not notice.

## Release

`make release` creates `dist/Shut Up Refiners.zip`. It is a FOMOD
installer: `fomod/` sits at the zip root, which is how mod managers detect an
installer, and each option is a folder beside it. Import it into
[Amethyst](https://github.com/ChrisDKN/Amethyst-Mod-Manager)/[Vortex](https://github.com/Nexus-Mods/Vortex)
or upload it to Nexus. For a manual install, copy the folder for the option you want into `GAMEDATA/MODS`.

The zip is named after the mod and carries no version, because a mod manager
names the installed mod after the archive file name and shows the version in a
column of its own. The version travels as the version of the Nexus release
instead.

## Game updates / versioning

The mod version is `VERSION` in the `Makefile`. The game version the script
targets is `GameVersion` in `src/shutuprefiners.lua.in`.

While the mod is unreleased, `VERSION` stays at `0.0.0`. When it is released,
the bump to the first version is a commit containing nothing but the version
change, on top of a tree that is otherwise finished. Publishing the release is
a separate step after that.

When No Man's Sky updates:

1. Fetch the new matching compiler from the AMUMSS repo (use
   `MBINCOMPILER_TAG=vX` to pin):
   `AMUMSS_HOME=~/AMUMSS linux/scripts/fetch_mbincompiler.sh`
   If the AMUMSS core itself changed, re-run the pipeline once so the
   linux patches re-verify (`apply_linux_patches.sh --verify`).
2. Re-derive the refiner events and counts (see below).
3. Update `Targets` in `src/shutuprefiners.lua.in`, and `TARGET_SOUNDS_*`,
   `TARGET_STATES_*`, `TARGET_WANT_*` and `MUTE_EVENT` in the `Makefile`.
4. Bump `GameVersion` in `src/shutuprefiners.lua.in`.
5. `make release`, install, test.

### Re-deriving the refiner events and counts

The event names, states and per-file counts are game data, not constants this
mod owns. To re-derive them:

```sh
PAK=~/.local/share/Steam/steamapps/common/"No Man's Sky"/GAMEDATA/PCBANKS/NMSARC.Precache.pak
hgpaktool -O /tmp/probe -f "*buildableparts/tech/refiner/entities/*" "$PAK"
hgpaktool -O /tmp/probe -f "*playercharacter/playercharacter/entities/*" "$PAK"
```

Then list the audio actions and the state each one sits in:

```sh
find /tmp/probe -name "*.entity.mbin" | while read f; do
  d=$(dirname "$f")
  (cd "$d" && ~/AMUMSS/MODBUILDER/MBINCompiler-linux -q -y -f -iMBIN "$(basename "$f")")
done

python3 - <<'EOF'
import glob, xml.etree.ElementTree as ET
for path in sorted(glob.glob('/tmp/probe/**/refiner*.entity.MXML', recursive=True)
                   + glob.glob('/tmp/probe/**/playercharacter.entity.MXML', recursive=True)):
    root = ET.parse(path).getroot()
    print(f"--- {path.split('/')[-1]} ---")
    for comp in root.iter('Property'):
        if comp.get('value') != 'GcTriggerActionComponentData':
            continue
        for sc in [c for c in comp.find('Property') if c.get('name') == 'States']:
            for state in sc.findall('Property'):
                for trig in [c for c in state if c.get('name') == 'Triggers']:
                    for tr in trig.findall('Property'):
                        for acont in [c for c in tr if c.get('name') == 'Action']:
                            for a in acont.findall('Property'):
                                if a.get('value') != 'GcPlayAudioAction':
                                    continue
                                snd = [x.get('value') for x in a.iter('Property')
                                       if x.get('name') == 'Sound']
                                print(f"  {state.get('_id'):16s} {snd[0]}")
EOF
```

Expected as of v7.06:

```
refiner1.entity.MXML
  REFINE_START     Obj_PortableRefinery_Start
  REFINE_STOP      Obj_PortableRefinery_Stop
  REFINE_NOFUEL    Obj_PortableRefinery_Stop
refiner2.entity.MXML
  REFINE_START     Obj_RefineryMedium_Start
  REFINE_STOP      Obj_RefineryMedium_Stop
refiner3.entity.MXML
  REFINE_START     Obj_RefineryLarge_Start
  REFINE_STOP      Obj_RefineryLarge_Stop
playercharacter.entity.MXML
  REFINE_START     Obj_PortableRefinery_Start
  REFINE_STOP      Obj_PortableRefinery_Stop
  REFINE_NOFUEL    Obj_PortableRefinery_Stop
```

`REFINE_NOFUEL` is not muted. It is the only reason the states have to be
named in the patch at all, because it shares its event name with `REFINE_STOP`.

If a count changes, update `TARGET_WANT_*` in the `Makefile` or `make verify`
fails loudly rather than muting half of them. If a state is renamed, update
`Targets` in the script and `TARGET_STATES_*` in the `Makefile`. If an event
is renamed, update `Targets` in the script and `TARGET_SOUNDS_*` in the
`Makefile`.