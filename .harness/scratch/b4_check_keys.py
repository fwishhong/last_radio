import json

zh = json.load(open('data/i18n/zh.json', encoding='utf-8'))
en = json.load(open('data/i18n/en.json', encoding='utf-8'))
for k in ['npc_status_emergency', 'npc_status_walking', 'npc_status_idle', 'npc_status_low_trust']:
    print(f'  zh: {k} = {zh.get(k, "MISSING")!r}')
    print(f'  en: {k} = {en.get(k, "MISSING")!r}')