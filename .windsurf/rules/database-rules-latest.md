---
trigger: always_on
---
# Database Quick Rules

Full reference: `.windsurf/skills/database-patterns/`

## Legacy Warning
`matches.players` is LEGACY. Do not write new code that depends on it.

## RLS Guard (do not remove)
Any policy using `jsonb_array_elements(m.players)` MUST guard with:
`CASE WHEN jsonb_typeof(m.players)='array' THEN m.players ELSE '[]'::jsonb END`

## Debug Shortcuts
- "cannot extract elements from a scalar" → RLS policy calling `jsonb_array_elements` on non-array JSON
- "Found 0 throw records" for local match → policy missing `match_players` membership check