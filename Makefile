# Shut Up Refiners
# Builds the FOMOD installer with the AMUMSS Linux port.
#
# What it does: rewrites the Wwise event name in every GcPlayAudioAction in the
# refiner entity MBINs so it points at INVALID_EVENT, a sentinel NMS itself
# uses for "no event". Wwise returns an invalid handle for an unknown event, so
# the refiner never posts a sound and runs silently.
#
# There is deliberately no volume knob here. NMS audio is Wwise, and per-event
# volume is authored in the Wwise project and compiled into the soundbanks, so
# it is not reachable from game data. GcPlayAudioAction carries only Sound,
# UseOcclusion and OcclusionRadius, the refiners have no TkAudioComponentData
# at all, the refiner scene has no audio emitters, and gcaudioglobals has no
# per-object mixer. Whether the event is posted is the only lever available,
# which makes this a mute mod rather than a quieter one.
#
# Usage:
#   make release      clean rebuild + verify + pack dist/ zip (default)
#   make verify       sanity-check the built outputs
#   make assets       regenerate the Nexus page images (header + gallery)
#   make clean        remove build/ and dist/
#
# Override the AMUMSS install location if needed:
#   make AMUMSS_HOME=/path/to/AMUMSS release
#
# Game-update playbook (see README.md):
#   1. fetch latest MBINCompiler into AMUMSS_HOME
#   2. bump GameVersion and the refiner event names in src/shutuprefiners.lua.in
#   3. bump VERSION below (the mod version, published on Nexus)
#   4. make release, import + deploy + test in game

AMUMSS_HOME ?= $(HOME)/AMUMSS
AMUMSS_LINUX ?= $(HOME)/Git/AMUMSS/linux

# The mod version, published as the version of the Nexus release. An
# unreleased build stays at 0.0.0; the first public release bumps this in a
# commit of its own. The version is deliberately not part of the mod name: the
# artifact is named after the mod alone (see FOMOD_ZIP), because a mod manager
# names the installed mod after the archive file name and shows the version in
# a column of its own.
VERSION      := 0.1.0

MOD_SET      := Shut Up Refiners

SRC_TEMPLATE := src/shutuprefiners.lua.in

BUILD := build
DIST  := dist
STAMP := $(BUILD)/.built

# The string each muted Sound is rewritten to. Must stay in sync with MuteEvent
# in src/shutuprefiners.lua.in; verify cross-checks the rendered script.
MUTE_EVENT := INVALID_EVENT

# The entity files this mod can patch, keyed by the name the variants select
# them by. TARGET_DIR and TARGET_FILE are where AMUMSS drops the EXML patch,
# which keeps the MBIN path with the .MBIN suffix swapped for .EXML.
#
#   target            tier     dir / file
#   REFINER1          small    planet biome refiner entities
#   REFINER2          medium
#   REFINER3          large
#   PLAYERCHARACTER   exosuit  the player character entity, which carries the
#                              personal refiner
TARGETS := REFINER1 REFINER2 REFINER3 PLAYERCHARACTER

TARGET_DIR_REFINER1 := MODELS/PLANETS/BIOMES/COMMON/BUILDINGS/PARTS/BUILDABLEPARTS/TECH/REFINER/ENTITIES
TARGET_FILE_REFINER1 := REFINER1.ENTITY.EXML
TARGET_DIR_REFINER2 := MODELS/PLANETS/BIOMES/COMMON/BUILDINGS/PARTS/BUILDABLEPARTS/TECH/REFINER/ENTITIES
TARGET_FILE_REFINER2 := REFINER2.ENTITY.EXML
TARGET_DIR_REFINER3 := MODELS/PLANETS/BIOMES/COMMON/BUILDINGS/PARTS/BUILDABLEPARTS/TECH/REFINER/ENTITIES
TARGET_FILE_REFINER3 := REFINER3.ENTITY.EXML
TARGET_DIR_PLAYERCHARACTER := MODELS/COMMON/PLAYER/PLAYERCHARACTER/PLAYERCHARACTER/ENTITIES
TARGET_FILE_PLAYERCHARACTER := PLAYERCHARACTER.ENTITY.EXML

# How many GcPlayAudioAction nodes each file is expected to have muted. The
# counts are game data, not constants this mod owns, so verify asserts them and
# a game update that adds or removes a refiner sound fails loudly rather than
# muting half of them.
TARGET_WANT_REFINER1 := 2
TARGET_WANT_REFINER2 := 2
TARGET_WANT_REFINER3 := 2
TARGET_WANT_PLAYERCHARACTER := 2

TARGET_TIER_REFINER1 := small
TARGET_TIER_REFINER2 := medium
TARGET_TIER_REFINER3 := large
TARGET_TIER_PLAYERCHARACTER := personal

# The refiner states each patch must touch, and the ones it must not.
#
# REFINE_NOFUEL is the refiner running dry. It posts the same
# Obj_PortableRefinery_Stop event as REFINE_STOP, so only the state name tells
# the two apart. That cue is deliberately kept, so if REFINE_NOFUEL ever shows
# up in a patch the state matching has gone wrong and the player is losing the
# sound they asked to keep.
TARGET_STATES_REFINER1 := REFINE_START REFINE_STOP
TARGET_STATES_REFINER2 := REFINE_START REFINE_STOP
TARGET_STATES_REFINER3 := REFINE_START REFINE_STOP
TARGET_STATES_PLAYERCHARACTER := REFINE_START REFINE_STOP

TARGET_STATES_ABSENT_REFINER1 := REFINE_NOFUEL
TARGET_STATES_ABSENT_REFINER2 :=
TARGET_STATES_ABSENT_REFINER3 :=
TARGET_STATES_ABSENT_PLAYERCHARACTER := REFINE_NOFUEL

# The event names that must NOT survive into a patch. If any of these is still
# in an EXML, the keyword path missed that node and that refiner is still going
# to be loud.
TARGET_SOUNDS_REFINER1 := Obj_PortableRefinery_Start Obj_PortableRefinery_Stop
TARGET_SOUNDS_REFINER2 := Obj_RefineryMedium_Start Obj_RefineryMedium_Stop
TARGET_SOUNDS_REFINER3 := Obj_RefineryLarge_Start Obj_RefineryLarge_Stop
TARGET_SOUNDS_PLAYERCHARACTER := Obj_PortableRefinery_Start Obj_PortableRefinery_Stop

# Installer variants. The label is the created folder name, the fomod source
# folder and the in-game MOD_FILENAME suffix, so it must match ModuleConfig.xml
# exactly.
#
#   Refiners                        the three refiners you place on a planet
#   Refiners and Personal Refiner   those, plus the Personal Refiner in your
#                                   Exosuit inventory
#
# The per-variant data is keyed by slot rather than by label, because a make
# variable name cannot contain a space and these labels are read by players.
VARIANT_SLOTS := 1 2

VARIANT1_LABEL := Refiners
VARIANT1_FILES := REFINER1 REFINER2 REFINER3
VARIANT1_LUA   := "REFINER1", "REFINER2", "REFINER3"
VARIANT1_DESC  := Silences the small, medium and large refiner you place on a planet

VARIANT2_LABEL := Refiners and Personal Refiner
VARIANT2_FILES := REFINER1 REFINER2 REFINER3 PLAYERCHARACTER
VARIANT2_LUA   := "REFINER1", "REFINER2", "REFINER3", "PLAYERCHARACTER"
VARIANT2_DESC  := Silences those, and the Personal Refiner in your Exosuit inventory

# Unquoted and quoted forms of the label list. The quoted one is for the shell,
# where a label with spaces has to stay one argument.
LABELS        := $(foreach s,$(VARIANT_SLOTS),$(VARIANT$(s)_LABEL))
LABELS_QUOTED := $(foreach s,$(VARIANT_SLOTS),"$(VARIANT$(s)_LABEL)")

RENDERED := $(foreach s,$(VARIANT_SLOTS),$(BUILD)/v$(s).lua)

# clean runs before build runs before verify, so release must not be parallel.
.NOTPARALLEL:

.PHONY: all release build verify assets clean

all: release

# The artifact is named after the mod and nothing else, for the same reason
# the mod name carries no version: the file name is what a mod manager shows
# as the mod name.
FOMOD_ZIP := $(DIST)/$(MOD_SET).zip

release: clean build verify
	@rm -rf "$(BUILD)/fomodz" && mkdir -p "$(BUILD)/fomodz/fomod"
	@set -e; \
	$(foreach s,$(VARIANT_SLOTS),mkdir -p "$(BUILD)/fomodz/$(VARIANT$(s)_LABEL)"; cp -a "$(BUILD)/$(MOD_SET) - $(VARIANT$(s)_LABEL)/." "$(BUILD)/fomodz/$(VARIANT$(s)_LABEL)/";)
	@cp ModuleConfig.xml "$(BUILD)/fomodz/fomod/"
	@mkdir -p "$(DIST)" && rm -f "$(FOMOD_ZIP)" && cd "$(BUILD)/fomodz" && zip -qr "$(shell pwd)/$(FOMOD_ZIP)" fomod $(LABELS_QUOTED)
	@echo "packed: $(FOMOD_ZIP) (version $(VERSION))"
	@python3 -c "import xml.dom.minidom; xml.dom.minidom.parse('$(BUILD)/fomodz/fomod/ModuleConfig.xml'); print('ModuleConfig.xml: well-formed XML')"

# Render the variant scripts from the single template. One pattern rule for
# every variant, keyed by slot: the file stem is the slot, so $* drives the
# substitutions. The guard turns a typo into a loud failure rather than a script
# with an empty file list.
$(BUILD)/v%.lua: $(SRC_TEMPLATE)
	@mkdir -p "$(BUILD)"
	@test -n "$(VARIANT$*_FILES)" -a -n "$(VARIANT$*_LUA)" -a -n "$(VARIANT$*_DESC)" -a -n "$(VARIANT$*_LABEL)" || { echo "ERROR: unknown variant slot '$*' - add VARIANT$*_LABEL, VARIANT$*_FILES, VARIANT$*_LUA and VARIANT$*_DESC to the Makefile" >&2; exit 1; }
	@sed -e 's/@VARIANT_LABEL@/$(VARIANT$*_LABEL)/' -e 's/@DESC@/$(VARIANT$*_DESC)/' -e 's/@FILES@/$(VARIANT$*_LUA)/' "$(SRC_TEMPLATE)" > "$@"

# One pipeline run builds every variant as an individual mod.
build: $(RENDERED)
	@test -d "$(AMUMSS_HOME)/MODBUILDER" || (echo "ERROR: no AMUMSS install at $(AMUMSS_HOME) (set AMUMSS_HOME=...)" >&2; exit 1)
	@test -x "$(AMUMSS_HOME)/MODBUILDER/MBINCompiler-linux" || (echo "ERROR: run $(AMUMSS_LINUX)/scripts/fetch_mbincompiler.sh with AMUMSS_HOME=$(AMUMSS_HOME) first" >&2; exit 1)
	@mkdir -p "$(BUILD)"
	@set -e; \
	if [ -d "$(AMUMSS_HOME)/ModScript" ]; then mv "$(AMUMSS_HOME)/ModScript" "$(AMUMSS_HOME)/ModScript.makebak"; trap 'rm -rf "$(AMUMSS_HOME)/ModScript"; mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"' EXIT; fi; \
	mkdir -p "$(AMUMSS_HOME)/ModScript"; \
	cp $(RENDERED) "$(AMUMSS_HOME)/ModScript/"; \
	$(foreach s,$(VARIANT_SLOTS),rm -rf "$(AMUMSS_HOME)/CreatedMODS/$(MOD_SET) - $(VARIANT$(s)_LABEL)";) \
	AMUMSS_HOME="$(AMUMSS_HOME)" "$(AMUMSS_LINUX)/buildmod.sh" --run-pipeline; \
	rm -rf "$(AMUMSS_HOME)/ModScript"; \
	if [ -d "$(AMUMSS_HOME)/ModScript.makebak" ]; then mv "$(AMUMSS_HOME)/ModScript.makebak" "$(AMUMSS_HOME)/ModScript"; fi; \
	trap - EXIT
	@set -e; \
	$(foreach s,$(VARIANT_SLOTS),rm -rf "$(BUILD)/$(MOD_SET) - $(VARIANT$(s)_LABEL)"; mkdir -p "$(BUILD)/$(MOD_SET) - $(VARIANT$(s)_LABEL)"; cp -a "$(AMUMSS_HOME)/CreatedMODS/$(MOD_SET) - $(VARIANT$(s)_LABEL)"/* "$(BUILD)/$(MOD_SET) - $(VARIANT$(s)_LABEL)/";)
	@touch "$(STAMP)"
	@echo "built: $(foreach s,$(VARIANT_SLOTS),$(BUILD)/$(MOD_SET) - $(VARIANT$(s)_LABEL) )"

# Path to one target's generated EXML inside one variant.
targetdir = $(TARGET_DIR_$(1))
targetfile = $(TARGET_FILE_$(1))
exml = $(BUILD)/$(MOD_SET) - $(VARIANT$(1)_LABEL)/$(call targetdir,$(2))/$(call targetfile,$(2))

# One check chain per (variant, target). The generated EXML is a minimal patch,
# so verify has five jobs:
#   1. the EXML was produced by THIS run, not carried over from a previous one
#   2. the expected number of Sound values were rewritten to the mute sentinel
#   3. none of the original refiner event names survived
#   4. the refiner states that should be muted are in the patch, and the one
#      that should be kept is not
#   5. no marker tags, which would leave the patch visibly annotated in game
#
# Job 1 covers the failure mode the others cannot see. The build copies out of
# $(AMUMSS_HOME)/CreatedMODS, which is a persistent directory this Makefile does
# not own. When a script changes nothing (a drifted keyword path, a typo, a bad
# struct name) AMUMSS logs "0 action(s) made", creates nothing, and leaves the
# PREVIOUS build's file sitting there. The copy then succeeds and jobs 2 to 5
# happily validate last week's output. The rendered script is always written
# before the pipeline runs, so anything older than it came from somewhere else.
#
# Job 2 is the load-bearing one. If a SPECIAL_KEY_WORDS path ever stops
# matching, AMUMSS silently applies the change to every node it can reach and
# ships that as the patch. The count is the only thing that catches it.
define VERIFY_TARGET
exml="$(call exml,$(1),$(2))"; \
if [ ! -f "$$exml" ]; then echo "MISSING $(2) EXML in $(VARIANT$(1)_LABEL)" >&2; exit 1; fi; \
if [ "$$exml" -ot "$(BUILD)/v$(1).lua" ]; then \
	echo "STALE $(2) EXML in $(VARIANT$(1)_LABEL) - older than the script that should have produced it." >&2; \
	echo "       AMUMSS most likely made no changes this run, so this is output from a" >&2; \
	echo "       previous build being picked out of $(AMUMSS_HOME)/CreatedMODS." >&2; \
	echo "       Clear $(AMUMSS_HOME)/CreatedMODS and rebuild; if it persists the script" >&2; \
	echo "       is not matching anything." >&2; \
	exit 1; \
fi; \
n=$$(grep -c 'name="Sound" value="$(MUTE_EVENT)"' "$$exml" || true); \
if [ "$$n" -ne "$(TARGET_WANT_$(2))" ]; then \
	echo "BAD $(2) ($(TARGET_TIER_$(2)) refiner) in $(VARIANT$(1)_LABEL): $$exml rewrites $$n Sound values, want $(TARGET_WANT_$(2))." >&2; \
	echo "       Too few means the keyword path missed a node and that refiner is still loud." >&2; \
	echo "       Too many means the keyword path stopped matching and is rewriting unrelated nodes." >&2; \
	exit 1; \
fi; \
for s in $(TARGET_SOUNDS_$(2)); do \
	if grep -qF "$$s" "$$exml"; then \
		echo "BAD $(2) ($(TARGET_TIER_$(2)) refiner) in $(VARIANT$(1)_LABEL): $$s still present - not every refiner sound was muted." >&2; \
		exit 1; \
	fi; \
done; \
for st in $(TARGET_STATES_$(2)); do \
	if ! grep -qF "_id=\"$$st\"" "$$exml"; then \
		echo "BAD $(2) ($(TARGET_TIER_$(2)) refiner) in $(VARIANT$(1)_LABEL): state $$st is missing from the patch." >&2; \
		echo "       The state matching has drifted, so the wrong refiner state is being muted." >&2; \
		exit 1; \
	fi; \
done; \
for st in $(TARGET_STATES_ABSENT_$(2)); do \
	if grep -qF "_id=\"$$st\"" "$$exml"; then \
		echo "BAD $(2) ($(TARGET_TIER_$(2)) refiner) in $(VARIANT$(1)_LABEL): state $$st is in the patch but must not be." >&2; \
		echo "       That state shares its event name with one that should be muted, so only the" >&2; \
		echo "       state name separates them. This means the player is losing a cue they" >&2; \
		echo "       asked to keep." >&2; \
		exit 1; \
	fi; \
done; \
if grep -q '!#' "$$exml"; then echo "marker tags present in $(2) in $(VARIANT$(1)_LABEL)" >&2; exit 1; fi
endef

# Every (variant, target) pair, expanded at make time so each value is baked in.
# The trailing semicolon separates one target's chain from the next.
VERIFY_ALL := $(foreach s,$(VARIANT_SLOTS),$(foreach t,$(VARIANT$(s)_FILES),$(call VERIFY_TARGET,$(s),$(t));))

verify: build
	@for n in "$$(sed -n 's:.*<moduleName>\(.*\)</moduleName>.*:\1:p' ModuleConfig.xml)" "$(MOD_SET)"; do \
		if printf '%s' "$$n" | grep -qE '[vV]?[0-9]+(\.[0-9]+)+'; then \
			echo "ERROR: the mod name must not carry a version: '$$n'" >&2; exit 1; \
		fi; \
	done
	@set -e; \
	$(foreach s,$(VARIANT_SLOTS),\
		for t in $(VARIANT$(s)_FILES); do \
			grep -qF "\"$$t\"" "$(BUILD)/v$(s).lua" \
				|| { echo "ERROR: $$t is not in the target list of variant $(VARIANT$(s)_LABEL) - VARIANT$(s)_FILES and VARIANT$(s)_LUA have drifted apart" >&2; exit 1; }; \
		done; \
		grep -qF '"$(MUTE_EVENT)"' "$(BUILD)/v$(s).lua" \
			|| { echo "ERROR: MuteEvent in $(SRC_TEMPLATE) does not match MUTE_EVENT in the Makefile ($(MUTE_EVENT))" >&2; exit 1; }; \
		kw=$$(tr '\n' ' ' < "$(BUILD)/v$(s).lua" | grep -o '\["SPECIAL_KEY_WORDS"\] *= *{[^}]*}' | head -1 | sed 's/,[[:space:]]*}/}/'); \
		if [ -z "$$kw" ]; then \
			echo "ERROR: no SPECIAL_KEY_WORDS found in $(BUILD)/v$(s).lua." >&2; \
			exit 1; \
		fi; \
		n=$$(printf '%s' "$$kw" | tr -cd ',' | wc -c); \
		n=$$((n + 1)); \
		if [ $$((n % 2)) -ne 0 ]; then \
			echo "ERROR: SPECIAL_KEY_WORDS in $(SRC_TEMPLATE) has $$n entries (odd) for variant $(VARIANT$(s)_LABEL)." >&2; \
			echo "       AMUMSS silently discards the last entry, the path stops matching, and" >&2; \
			echo "       the Sound change is applied everywhere the path can reach." >&2; \
			exit 1; \
		fi; \
	)
	@set -e; $(VERIFY_ALL)
	@echo "verify: OK ($(words $(TARGETS)) refiners, $(VARIANT1_FILES) / $(VARIANT2_FILES) per variant, fresh this run, no marker tags)"

# Nexus page images from the source screenshot. The generated images are
# build artifacts and are not tracked; the source screenshot and the
# typeface are.
assets: assets/src/gallery-refiners.jpg assets/generate.py
	python3 assets/generate.py

clean:
	rm -rf "$(BUILD)" "$(DIST)"