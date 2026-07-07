"""Comprehensive B4 audit."""
import json

zh = json.load(open('data/i18n/zh.json', encoding='utf-8'))
en = json.load(open('data/i18n/en.json', encoding='utf-8'))

# Polish spec §7 i18n keys list
expected = {
    # §7.1 Cover (3)
    'cover_monologue_line1': 'cover',
    'cover_monologue_line2': 'cover',
    'cover_monologue_attribution': 'cover',
    # §7.2 Tutorial Step 4 (4)
    'tut_step4_title': 'tut_step4',
    'tut_step4_desc': 'tut_step4',
    'tut_step4_victor_line': 'tut_step4',
    'tut_step4_static_noise': 'tut_step4',
    # §7.3 Night Report (13 = 10 + 3)
    'report_victor_log_1': 'report_victor_log',
    'report_victor_log_2': 'report_victor_log',
    'report_victor_log_3': 'report_victor_log',
    'report_victor_log_4': 'report_victor_log',
    'report_victor_log_5': 'report_victor_log',
    'report_victor_log_6': 'report_victor_log',
    'report_victor_log_7': 'report_victor_log',
    'report_victor_log_8': 'report_victor_log',
    'report_victor_log_9': 'report_victor_log',
    'report_victor_log_10': 'report_victor_log',
    'report_survivors_joined': 'report_survivors',
    'report_survivors_left': 'report_survivors',
    'report_survivors_lost': 'report_survivors',
    # §7.5 NPC UI (4)
    'npc_status_emergency': 'npc_ui_status',
    'npc_status_walking': 'npc_ui_status',
    'npc_status_idle': 'npc_ui_status',
    'npc_status_low_trust': 'npc_ui_status',
    # §7.6 NPC Join notifications (7)
    'log_ally_join_nora': 'npc_join',
    'log_ally_join_elias': 'npc_join',
    'log_ally_join_lily': 'npc_join',
    'log_ally_join_tom': 'npc_join',
    'log_ally_left_daniel': 'npc_join',
    'log_ally_lost_tom': 'npc_join',
    'log_victor_lost': 'npc_join',
    # §7.7 Survivor briefs (6)
    'survivor_nora_brief': 'survivor_brief',
    'survivor_elias_brief': 'survivor_brief',
    'survivor_lily_brief': 'survivor_brief',
    'survivor_tom_brief': 'survivor_brief',
    'survivor_daniel_brief': 'survivor_brief',
    'survivor_victor_brief': 'survivor_brief',
}

missing_zh = []
missing_en = []
for k, group in expected.items():
    if k not in zh:
        missing_zh.append((k, group))
    if k not in en:
        missing_en.append((k, group))

print(f'Expected {len(expected)} i18n keys from polish spec §7')
print(f'Missing in zh: {len(missing_zh)}')
for k, g in missing_zh:
    print(f'  zh: {k}  ({g})')
print(f'Missing in en: {len(missing_en)}')
for k, g in missing_en:
    print(f'  en: {k}  ({g})')

# Check orphan keys in zh that look like polish spec but aren't in the expected set
polish_ish = [k for k in zh.keys() if any(p in k for p in ['cover_monologue', 'tut_step4', 'report_victor_log', 'report_survivors', 'npc_status', 'log_ally_', 'log_victor', 'survivor_'])]
print(f'\nPolish spec keys present in zh: {len(polish_ish)}')
print('  (showing all)')
for k in sorted(polish_ish):
    in_expected = k in expected
    marker = ' ' if in_expected else '*'
    print(f'  {marker} {k}')