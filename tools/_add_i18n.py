#!/usr/bin/env python3
"""Add English fields to day_cards.json and NightShiftLevels.gd.
Idempotent — re-running skips already-translated entries.
"""
import json
import re
import sys

CARDS_PATH = r"C:\Users\Administrator\Desktop\codex\last_radio v2\data\night_shift\day_cards.json"
LEVELS_PATH = r"C:\Users\Administrator\Desktop\codex\last_radio v2\scripts\NightShiftLevels.gd"


DAYCARD_EN = {
    "start": ("Begin Watch", "No extra preparation. Go straight into the night."),
    "door_reinforce": ("Reinforce Front Door", "Front door holds longer before breaking."),
    "window_brace": ("Brace Windows", "Left and right windows get sturdier. Nora repairs them faster."),
    "battery_buffer": ("Backup Battery", "Generator is less likely to fully drain and lose power."),
    "generator_tune": ("Service Generator", "Generator drains slower. Easier to recover from a blackout."),
    "radio_booster": ("Raise the Antenna", "Radio calls last longer and connect more easily."),
    "workbench": ("Tidy Workbench", "Slight boost to repair and operation speed."),
    "antenna_anchor": ("Anchor Antenna", "Antenna drops less. Calls are harder to lose."),
    "storage": ("Organize Storage", "Find extra planks. Emergency repairs last longer."),
    "medbay": ("Set up Medbay", "Spend medicine. Refugee trust and ally stability."),
    "rescue_bleachers": ("Rescue Bleachers", "Save people hiding in the bleachers. Uses medicine and raises exposure."),
    "storage_sweep": ("Scavenge Equipment", "Gain planks and parts. Nora tires more easily tonight."),
    "open_route": ("Publish Route", "Broadcast the coordinates for response, but exposure rises."),
    "keep_silent": ("Stay Silent", "Lower exposure, but might miss outside responses."),
    "back_door_bar": ("Bar Back Door", "Back door holds longer."),
    "generator_cage": ("Cage Generator", "When the back door is in trouble, generator loses less."),
    "runner_path": ("Clear Path", "Player movement speed increases."),
    "medbay_lamp": ("Medbay Lamp", "Fewer medbay alerts. Slight trust gain."),
    "nora_kit": ("Organize Medkit", "Nora handles medbay and windows faster."),
    "quiet_hours": ("Quiet Hours", "First half of the night: less random noise, lower exposure."),
    "salvage_planks": ("Salvage Bleacher Planks", "Lots of planks, but spend trust and raise exposure."),
    "double_brace": ("Double Window Brace", "Window emergency seals last longer."),
    "victor_cache": ("Mark Supply Crate", "Find parts at Victor's coordinates. Storage pressure lowers."),
    "signal_battery": ("Signal Battery", "During blackout, antenna drops slower."),
    "cable_route": ("Re-route Cables", "Antenna and radio repair faster."),
    "elias_tools": ("Tools for Elias", "Elias auto-handles radio and antenna faster."),
    "final_barricade": ("Final Barricade", "All doors and windows start sturdier."),
    "all_hands": ("All Hands", "Nora and Elias auto-handle things faster."),
    "radio_beacon": ("Open Beacon", "Final night radio window is longer, but exposure spikes."),
}


# (title_en, briefing_en, story_intro_en, night_goal_en,
#  [beat0_en, beat1_en, beat2_en],
#  success_report_en, failure_report_en, [story_start_en...])
LEVEL_EN = {
    "第一夜：三盏灯": (
        "Night 1: Three Lights",
        "Tutorial night: hold the front door, left window, and generator. Survive until dawn and Nora will stay.",
        "During the day you wired temporary power into the old stadium. Twenty-seven people huddle under the bleachers, all staring at the three places still lit: the front door, the left window, the generator. Nora is still outside the window. She says if you last until dawn she will believe this is not another place that goes dark.",
        "Only hold the front door, the left window, and the generator. Learn to move, repair, and judge priorities.",
        [
            "When the front door takes its first hit, someone in the bleachers bites their sleeve without crying out.",
            "A flashlight flickers outside the left window. Nora is still out there. She has not left.",
            "Near dawn, Nora knocks three times on the window frame: do not open the door, I will find the side entrance.",
        ],
        "Dawn breaks. Nora enters through the equipment room side door, her sleeve cut by wire. She drops a bent nail on the duty desk. She does not say thank you. She only says: next night, the windows are mine.",
        "Lights out. Nora is still outside the window. Her last knock was not asking you to open the door; it was telling the people inside to stay silent.",
        [
            "Night one begins. Only three lights remain in the stadium: the door, the window, the generator.",
            "Nora does not call for help, only says through the boards: let me see if you can hold.",
        ],
    ),
    "第二夜：右窗的人": (
        "Night 2: The Right Window",
        "The right window joins. Nora will help watch the most pressured window.",
        "During the day, Nora helps scrape blood from the left window. She points at the changing room on the right: children and elders sleep there. If the window hits, they wake.",
        "The right window adds pressure. Learn to share the windows with Nora.",
        [
            "The right window frame taps lightly. Nora glances at the sleeping children before rushing over.",
            "In the few seconds between hits, a child asks if there will be applause after dawn. Nora says yes.",
            "The left and right windows alternate impacts, but the crowd stops panicking.",
        ],
        "Right window held. In the morning, that child slips a whistle to Nora: next time, call me before the window hits.",
        "The bedding behind the right window is flipped open by cold wind. Nora keeps calling names until no one answers.",
        [
            "Night two begins. Nora tightens her sleeves and stands between the right window and the crowd.",
            "She says: if I run the wrong way, just call my name.",
        ],
    ),
    "第三夜：接住声音": (
        "Night 3: Hold the Signal",
        "The radio joins. After connecting the radio, Elias will find the stadium.",
        "During the day, the radio speaks a full name for the first time: Elias Reed. He has tools. Give him a lit coordinate and he will follow the light.",
        "Trade off between radio goals and door/window survival.",
        [
            "When the radio lights up, Nora does not look back. She only says: hold him, I will watch the window.",
            "Another voice cuts into the channel, calling himself Victor. He heard the old stadium.",
            "Elias's breathing draws closer. He says: if the knock is three shorts and one long, it is me.",
        ],
        "Elias knocks at the side door before dawn, his arms wrapped in soaked cables. Victor does not appear, only says on the other end: one more light on the map.",
        "The radio lit up one last time. Elias was still reporting coordinates. Only Victor remained on the channel, repeating the stadium's name.",
        [
            "Night three begins. The radio wave looks like a line about to snap.",
            "Elias repeats through the static: do not turn off the lights. I can follow the bright spot.",
        ],
    ),
    "第四夜：屋顶的线": (
        "Night 4: The Roof Line",
        "The antenna joins. Don't let the signal drop or the radio becomes static.",
        "Elias climbs the bleachers during the day, his fingers cut by wire. Victor's voice is clearer than ever: I can see your lights.",
        "The antenna joins. Hold the signal before a radio call comes in.",
        [
            "When the antenna sags, Victor's voice immediately pulls away.",
            "Victor reads out a list of street names — not routes, but ways people can still find each other.",
            "Elias whispers: I heard him. We are not an island.",
        ],
        "The roof antenna held. Strangers begin to walk toward your light.",
        "After the antenna wire snapped, the stadium was erased from the map.",
        ["Night four begins. The roof wind whips the antenna like a string about to snap."],
    ),
    "第五夜：器材通道": (
        "Night 5: The Equipment Tunnel",
        "The back door joins. It is closest to the generator; if it falls, the power goes down.",
        "Victor says supplies will come from the equipment tunnel side. By dusk you spot new scratch marks on the back door.",
        "The back door joins the line. It cannot be ignored.",
        [
            "When the back door is hit for the first time, Elias looks up at the generator.",
            "Victor reports the location of a green supply crate.",
            "Cold wind sweeps in from the tunnel. Nora carries the closest child away.",
        ],
        "The equipment tunnel held. You found medicine and cables at Victor's coordinates.",
        "After the back door fell, the generator area went dark first.",
        ["Night five begins. Chain-dragging sounds come from outside the back door."],
    ),
    "第六夜：医务角的灯": (
        "Night 6: Medbay Light",
        "The medbay joins. It does not fail instantly, but it steals your time.",
        "Nora brings back a feverish girl. That small lamp must hold too.",
        "Handle soft pressure. Do not let the injured drag down the line.",
        [
            "A muffled cough comes from the medbay. Nora's step pauses, then runs toward the window.",
            "The girl wakes up, humming a melody no one recognizes.",
            "Nora pushes the medicine box into a place you can see.",
        ],
        "The medbay light did not go out. By dawn, everyone finally dares to breathe.",
        "After the medbay dimmed, Nora never looked up at the window again.",
        ["Night six begins. The medbay's small light is on."],
    ),
    "第七夜：最后一块板": (
        "Night 7: The Last Plank",
        "Storage joins. Planks are limited; every seal counts.",
        "Storage holds only half a stack of planks. Victor's note says: do not keep the last board for yourself.",
        "Storage and plank resources enter the game.",
        [
            "A collapse echoes from storage. Everyone glances at that small stack at the same time.",
            "Inside the supply crate's lining is an old photo, with a message on the back for the next lit place.",
            "Elias hands you a board: this is not wood, it is a minute.",
        ],
        "Planks were not enough, but you used every one where it mattered.",
        "Storage emptied. The doors and windows still echo. The last board could not buy dawn.",
        ["Night seven begins. Every plank is a stretch of time."],
    ),
    "第八夜：灯越亮，影越多": (
        "Night 8: The Brighter the Light, The More Shadows",
        "No new locations. Every system takes turns pressing. The second half is no longer quiet.",
        "Two more groups arrived during the day, all of them following the stadium's light. The light saved them, and drew the darkness further out toward the bleachers. Victor was silent for a long time, then said: tonight you will be seen.",
        "Hold the existing systems; expect pressure in waves.",
        [
            "The doors and windows come under sudden, coordinated assault.",
            "Someone inside asks how long the light will last.",
            "Victor signals that he has also lit a light of his own, somewhere far away.",
        ],
        "Every system took a hit, but the stadium's light held until dawn. Shadows stay where they are.",
        "The light held long enough for the people inside, but Victor's channel went dark first.",
        ["Night eight begins. The bleachers' shadows are longer than usual."],
    ),
    "第九夜：有人在追信号": (
        "Night 9: Someone is Following the Signal",
        "Exposure backlash, plus the chain between power, antenna, and radio.",
        "Elias notices someone tracking your frequency in reverse. Victor says it is fine, and turns his own radio brighter.",
        "Hold the generator / antenna / radio chain together.",
        [
            "The antenna signal drops suddenly. Elias hears another band sweeping in.",
            "Victor admits his position has been exposed.",
            "Nora has everyone memorize Victor's call sign.",
        ],
        "Power and signal did not both cut out. Victor hands the last coordinates to Elias.",
        "Blackout swallowed the signal, and the coordinates Victor left behind.",
        ["Night nine begins. Voltage and signal are bound together."],
    ),
    "第十夜：名单": (
        "Night 10: The Names",
        "Final test of all systems. Complete the chapter's final broadcast.",
        "Before the final night, Victor pushes his channel to max power. He only lets Elias copy the names: Nora, Elias, the old stadium, everyone still under a light.",
        "Hold every hotspot. Finish the chapter's final broadcast.",
        [
            "Victor starts broadcasting the stadium coordinates and the names.",
            "The tracking signal turns toward Victor.",
            "Victor's last call: Nora at the window, Elias on the frequency, you at the lights.",
        ],
        "Dawn. The stadium still stands. The radio still glows. Victor Hale's channel never returned, but his name is written as the first line of the duty log.",
        "The final night did not last until dawn. Victor drew the trackers away, but the stadium's lights went out first.",
        ["Night ten begins. The sounds outside the stadium press in from every direction."],
    ),
}


def esc(value):
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


# ---- day_cards.json --------------------------------------------------

with open(CARDS_PATH, "r", encoding="utf-8") as f:
    cards = json.load(f)

for c in cards["cards"]:
    cid = c["id"]
    if cid in DAYCARD_EN:
        c["name_en"], c["body_en"] = DAYCARD_EN[cid]

with open(CARDS_PATH, "w", encoding="utf-8") as f:
    json.dump(cards, f, ensure_ascii=False, indent=2)
    f.write("\n")

print(f"Updated {len(cards['cards'])} day cards")


# ---- NightShiftLevels.gd -----------------------------------------------

with open(LEVELS_PATH, "r", encoding="utf-8") as f:
    src = f.read()


def patch_field(text, key, en_key, new_value):
    # Replace a single occurrence of `"key": "...",` with the same line plus
    # an `_en` line on the next line. Indent is captured from any leading
    # whitespace and reused on the new line. Operates on a sub-block that
    # starts at the `"key":` token (no leading newline in scope).
    pattern = r'([ \t]*)"' + re.escape(key) + r'":\s*"((?:[^"\\]|\\.)*)",'
    def repl(m):
        prefix = m.group(1)
        return (prefix + '"' + key + '": "' + m.group(2) + '",\n'
                + prefix + '"' + en_key + '": "' + esc(new_value) + '",')
    new_text, n = re.subn(pattern, repl, text, count=1)
    if n != 1:
        print(f"  WARN patch_field({key}) replaced {n} times")
    return new_text


for title_zh, payload in LEVEL_EN.items():
    (title_en, briefing_en, story_intro_en, night_goal_en,
     beats_en, success_report_en, failure_report_en, story_start_en) = payload
    title_marker = '"title": "' + title_zh + '"'
    idx = src.find(title_marker)
    if idx < 0:
        print("WARN: not found:", title_zh)
        continue

    # Walk BACK from idx to find the opening `{` of this level entry.
    # The level structure is: `{ "title": ..., "briefing": ..., ... }`.
    open_idx = idx
    while open_idx > 0 and src[open_idx] != "{":
        open_idx -= 1
    # Walk FORWARD from open_idx to find the matching `}`.
    depth = 0
    j = open_idx
    while j < len(src):
        if src[j] == "{":
            depth += 1
        elif src[j] == "}":
            depth -= 1
            if depth == 0:
                break
        j += 1
    # block spans [open_idx, j] inclusive.
    block = src[open_idx:j+1]
    # We will splice new_block back at [open_idx .. j] in src.
    new_block = block

    new_block = patch_field(new_block, "title", "title_en", title_en)
    new_block = patch_field(new_block, "briefing", "briefing_en", briefing_en)
    new_block = patch_field(new_block, "story_intro", "story_intro_en", story_intro_en)
    new_block = patch_field(new_block, "night_goal", "night_goal_en", night_goal_en)
    new_block = patch_field(new_block, "success_report", "success_report_en", success_report_en)
    new_block = patch_field(new_block, "failure_report", "failure_report_en", failure_report_en)

    # Append story_start_en as a new field at the end of the entry.
    # We capture the indent of the last existing field, e.g. "\n\t\t" from
    # the closing "duration" line, and use the same indent for the new key.
    last_indent_match = re.search(r'\n([ \t]+)"duration":', new_block)
    if last_indent_match:
        indent = last_indent_match.group(1)
    else:
        indent = "\n\t\t"
    entries = ",".join([indent + '\t"' + esc(s) + '"' for s in story_start_en])
    # Insert before the final "\n\t}," closing.
    new_field = indent + '"story_start_en": [' + entries + indent + '],'
    new_block = new_block.rstrip()
    if new_block.endswith("}"):
        new_block = new_block[:-1].rstrip() + ",\n" + new_field + "\n\t\t}"

    # Append story_beats .text_en to each beat. Beats are dicts on a single
    # line: {"id": "first_hit", "at_ratio": 0.18, "text": "..."}. The match
    # captures the leading ", " (group 1) and the text value. We re-emit the
    # match unchanged, then insert `,\n` + indent + the new text_en field.
    # The original `},` closing the dict is still in the source after the
    # match, so we DON'T add a trailing comma.
    state = {"beat_idx": 0}
    def beat_repl(m):
        # m.group(1) is the leading `,\t\t\t` — strip only the comma, keep
        # the indent tabs, so the new line aligns with the existing fields.
        sep = m.group(1)
        indent = sep[1:]  # drop the leading comma, keep the tabs/spaces
        en = beats_en[state["beat_idx"]] if state["beat_idx"] < len(beats_en) else ""
        state["beat_idx"] += 1
        return m.group(0) + ',\n' + indent + '"text_en": "' + esc(en) + '"'
    beat_count_before = new_block.count('"text":')
    new_block, n_beats = re.subn(r'(,\s+)"text":\s*"([^"]+)"', beat_repl, new_block, count=3)
    if n_beats < 3:
        print(f"  WARN beat_repl: only {n_beats} of 3 beat texts patched (had {beat_count_before} 'text' fields)")

    src = src[:open_idx] + new_block + src[j+1:]

with open(LEVELS_PATH, "w", encoding="utf-8") as f:
    f.write(src)

print("Updated 10 night levels with English fields")