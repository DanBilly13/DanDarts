# Clubs: Design

**Date:** 2026-11-01
**Status:** Draft for review (iOS first, then Android; shared Supabase backend)
**Mockups:** Design artifact "DartFreak App Screens", artboards 18-24 (https://claude.ai/artifact/GMXjoFAgChZzNWYuxjT21x): Clubs tab, Find a club, Create a club, Club page (member), Club page (admin, invite-only), Friends tab with "People from your clubs". The optional sign-up step is artboard 24.

## Goal

Let a player say which club or team they play with, and let the app suggest other players from the same club as friends. Friends are the engine of the app (remote matches need friends), and darts is played in pub teams, darts clubs and groups of mates, so a club is the natural place to find them. Joining must be easy: search and one tap, with a code or link as the second route.

## Decisions (agreed in discussion)

| Decision | Choice | Why |
|---|---|---|
| What a club is | A pub team, a darts club or a group of mates. Not a league | Matches how people actually play |
| Visibility | **Open** (searchable, one-tap join) or **Invite-only** (hidden from search, link or code). The creator picks, Open is pre-selected, changeable later | No barriers for clubs that want members, privacy for groups of mates |
| Approval | None. Open clubs go live immediately, joining is instant | The user does not want pain points |
| Membership | A player can be in several clubs, maximum 5 | Pub team plus club plus mates |
| Identity | Name plus optional town. Names are not unique | Pub names repeat ("The Crown"); the town tells them apart |
| What non-members see (Open club) | Name, town, member count, up to 3 avatars (no names). Full member list only after joining | Lets someone recognise their club without exposing a roster |
| Findable by me | Switch "Let club members find me", default on. Off removes me from previews and suggestions | Easy opt-out |
| Suggestions | List "People from your clubs" in the Friends tab. Shows display name, avatar, shared club. Dismissable | Chosen over notifications |
| Names | Suggestions and member lists show the person's display name and avatar | User rejected nickname-only |
| Navigation | Clubs gets its own tab. Order on both apps: Games, Friends, Clubs, Remote, History. On Android, Profile moves out of the bottom bar into an avatar button in the top bar, as on iOS | User's choice; Android's bar already has 5 items, so this keeps it at 5 and matches iOS |
| Sign-up | Optional, skippable "Part of a club?" step. Plus an "I'm 13 or over" tick-box | Privacy policy says 13+, nothing checks it |
| Guardrails | Report button, name filter, admin can remove members, daily friend-request cap, no pre-approval | Not the wild west, no extra taps |

## Behaviour

**Create.** Name 3-40 characters, trimmed; town optional, up to 40. The name must pass the word filter. If an Open club with the same normalised name and town exists, show "Did you mean...?" with a Join button and block the duplicate. Invite-only duplicates are allowed because they are hidden. The same rule applies when an Invite-only club is switched to Open: if an Open club with the same name and town exists, `set_club_visibility` returns `duplicate` and the club stays Invite-only. The creator becomes admin and a member. Every club gets a join code.

**Find.** Search by name or town, 2+ characters, Open clubs only, 20 results, most members first. Each row: name, town, member count, up to 3 avatars, Join. If nothing matches, offer "Create 'X' as a new club". A "Have a code?" box joins any club, Open or Invite-only.

**Join.** Open: one tap, maximum 5 clubs (show a clear message at 5). By code or link: works for both visibilities. Unknown or old code shows "That code doesn't work. Ask the club for a new one."

**Share.** Every club has a code (6 characters from `ABCDEFGHJKMNPQRSTUVWXYZ23456789`, case-insensitive, unique) and a link `https://www.dartfreak.com/c/<CODE>`. Unlike the single-use friend invite, a club code works for many people. The admin can regenerate it; the old one stops working. Any member can share the club's link, Open or Invite-only, so a group of mates can bring each other in. Only the admin sees the code itself and the Regenerate button; if a link leaks, the admin regenerates the code.

**Club page.** Members after joining, each row with Add, "Request sent" or "Friend" (reusing the friendship state). Shared-friend count. Report club, Leave club. Admin adds: switch Open/Invite-only, code and Regenerate, remove a member.

**Leave, remove, delete.** A database trigger on membership deletes handles everything uniformly (leaving, removal, account deletion): if the club has no admin left, promote the longest-standing member; if it has no members, delete the club. A removed member of an Open club can rejoin; the admin can switch to Invite-only and regenerate the code to keep someone out.

**Suggestions.** Server-side query returns up to 20 people who share at least one club with me, ordered by number of shared clubs then most recent join. Excludes: me, anyone I have any friendship row with (accepted, pending, rejected or blocked, either direction), anyone who switched off "find me", and anyone I dismissed. The Friends tab shows the top 3 with "See all N". Each row has Add (sends a normal friend request) and a dismiss (x) that hides that person for good.

**Blocks.** Blocking works as today. A blocked person never appears in my suggestions, and I never appear in theirs.

**Friend-request cap.** Why: Open clubs let anyone join and see the member list, so without a cap a stranger could join a big club and send a request to everyone. A database trigger on `friendships` inserts rejects a requester's 51st request in 24 hours with the error `friend_request_limit`; clients show "You've sent a lot of requests today. Try again tomorrow." Applies to every friend request, including invite claims. Today there is no limit at all. The number is 50, not 20, so a new member of a 25-person pub team can add the whole team in one go; if it proves too tight or too loose it is one constant in one trigger.

**Report.** "Report club" on the club page, "Report" on a member row or suggestion. Inserts a row in `reports` (who, what, optional reason); a confirmation toast, no further UI. The owner reads reports in the Supabase SQL editor and removes clubs or accounts by hand.

**Name filter.** `create_club` checks the normalised name against a `blocked_words` table the owner maintains; a hit returns `name_not_allowed` and the app asks for a different name. Applies to club creation and to renaming if added later.

**Sign-up.** (1) Every new account must tick "I'm 13 or over" before the account is created; nothing is stored. It sits where the existing "By continuing, you agree to the Terms" text is, gating the email, Google and Apple buttons. Exact screens to confirm in the plan: iOS `SignUpView`; Android's Welcome, SignUp and Google paths (Google can reach account creation from the SignIn screen). (2) After profile setup and before the permissions screen, new accounts see a skippable "Part of a club or team?" step (artboard 24): the Find a club search with a Joined state on rows, "Create a club", "Have a code?", Continue and Skip for now. Existing users get no forced step; the empty Clubs tab explains the feature.

## Data model (migrations 093 onward, `supabase_migrations/`, applied by hand in the SQL editor)

```
clubs(id uuid pk default gen_random_uuid(),
      name text not null check (char_length(name) between 3 and 40),
      name_key text not null,            -- lower case, accents and punctuation stripped
      town text null check (char_length(town) <= 40), town_key text null,
      visibility text not null default 'open' check (visibility in ('open','invite')),
      join_code text not null unique,
      member_count integer not null default 0,   -- kept by trigger
      created_by uuid null references users(id) on delete set null,
      created_at timestamptz not null default now())
unique index on (name_key, coalesce(town_key,'')) where visibility = 'open'

club_members(club_id uuid references clubs on delete cascade,
             user_id uuid references users on delete cascade,
             role text not null default 'member' check (role in ('admin','member')),
             joined_at timestamptz not null default now(),
             primary key (club_id, user_id))
club_suggestion_dismissals(user_id, suggested_user_id, created_at, pk both, both FK users on delete cascade)
reports(id, reporter_id null fk users on delete set null, target_type check in ('club','user'), target_id uuid, reason text, created_at)
blocked_words(word text primary key)
users.club_discoverable boolean not null default true
```

**Triggers:** maintain `member_count`; on `club_members` delete, promote an admin or delete the empty club; on `friendships` insert, enforce the daily cap; limit 5 clubs per user on `club_members` insert.

**RLS:** tables are not directly writable by clients. `clubs` and `club_members` are readable only by members (via a `security definer` helper `is_club_member(club_id)` to avoid policy recursion). Everything else goes through RPCs, so non-members never receive a member list. `reports` is insert-only for the reporter.

**RPCs** (house convention from migrations 041, 089, 091: `SECURITY DEFINER`, `SET search_path = public`, `REVOKE ALL ... FROM PUBLIC; GRANT EXECUTE ... TO authenticated`): `search_clubs(p_query)`, `get_club_preview(p_club_id)`, `create_club(p_name, p_town, p_visibility)`, `join_club(p_club_id)`, `join_club_by_code(p_code)`, `leave_club(p_club_id)`, `set_club_visibility(p_club_id, p_visibility)`, `regenerate_club_code(p_club_id)`, `remove_club_member(p_club_id, p_user_id)`, `club_suggestions(p_limit)`, `dismiss_club_suggestion(p_user_id)`, `report_content(p_target_type, p_target_id, p_reason)`. Join and create RPCs return a result code string like `claim_invite` does (`ok`, `full`, `invalid_code`, `name_not_allowed`, `duplicate`, ...).

**Account deletion.** Memberships and dismissals cascade from `users`; `clubs.created_by` becomes null; the membership trigger fixes admin and empty clubs. `delete-account` needs no new code, but add a test case to the verification script.

**Verification script** `VERIFY_clubs.sql` alongside the migrations, in the style of the existing `VERIFY_*.sql` files.

## Components

**iOS** (`DanDart/`): new `Services/ClubsService.swift` (`@MainActor ObservableObject`, mirrors `FriendsService`; `Codable` models `Club`, `ClubPreview`, `ClubMember`, `ClubSuggestion` in `Models/`); new `Views/Clubs/` with `ClubsTabView`, `FindClubView`, `CreateClubView`, `ClubDetailView`, `ClubSignUpStepView`; a "People from your clubs" section in `FriendsListView`; a Settings toggle for `club_discoverable`; Report actions on the club page and member rows. Reuse `PlayerCard`, `AppButton`, `EmptyState`, `DartTextField`, `ShareSheet`, and the search field style from `FriendSearchView`.

**Tabs.** `MainTabView` uses magic integers for tabs (tags 0-3, plus the `logTabScreen` names, `rootNavTitle`, `toolbarContent`, toast suppression, notification routing and `handleToastNavigation`). Inserting Clubs at index 2 shifts Remote and History. First task in the plan: replace the integers with an enum, then add the tab.

**Links.** Handle `https://www.dartfreak.com/c/<code>` and `dartfreak://club?code=<code>` next to the existing invite handling in `DartFreakApp.swift` (three entry points: web activity, `onOpenURL`, custom scheme), store the code in a pending store like `PendingInviteStore`, and join after sign-in. Add `/c/*` to the website's apple-app-site-association.

**Android** (`app/`, `data/`): navigation first. `TopLevelDestination` (Games, Remote, Friends, History, Profile) becomes Games, Friends, Clubs, Remote, History, and Profile becomes an avatar button in the top bar of the top-level screens that opens the existing Profile route (iOS opens it as a full-screen cover from the avatar). This also touches the exhaustive `when (destination)` in `DartFreakApp.kt`, the `isOnTopLevelTab` list used to gate the challenge toast, and the stale "three tabs" comments. Then `data/clubs/ClubsRepository` (`Result<T>` wrapper with typed errors, like `FriendsRepository`), `ui/clubs/` screens and view models, a section in the Friends screen, Report actions, a Settings switch, new `Route` entries and `ErrorReporting` coverage. Android has **no invite or deep-link handling today** (only `dartfreak://reset-password`), so club links need an https App Links intent-filter with `autoVerify` for `www.dartfreak.com/c/*` and an `assetlinks.json` on the website, plus `ACTION_SEND` sharing and clipboard copy, none of which exist yet.

**Website** (`DartFreak-Web`): a `/c/[code]` page that says which club the link is for and offers "Open in DartFreak" or the store links, so a link works on a phone without the app.

**Analytics** (same style as the existing events, mirrored on both platforms): `club_created(visibility)`, `club_joined(source: search|code|link|signup, visibility)`, `club_left`, `club_shared`, `club_suggestions_viewed(count)`, `club_suggestion_added`, `club_suggestion_dismissed`, `club_reported(target_type)`. No search text is logged. Register `visibility`, `source` and `target_type` as custom dimensions later.

## Store and legal checklist

- **Terms:** add a Clubs section, a zero-tolerance sentence for objectionable content, "we act on reports and may remove clubs and accounts", and a minimum age of 13; update the "last updated" date. Both apps' copies.
- **Privacy policy:** club membership and suggestions, the "find me" switch, expand "Children's Privacy" beyond one line.
- **Apple:** guideline 1.2 (filter, report, block, contact) is met by the filter, Report and the existing Block and contact address. Update the privacy label; re-answer the age-rating questionnaire for user-generated content. No tracking prompt needed.
- **Google Play:** user-generated-content policy (terms acceptance, moderation, in-app report and block). Update the Data safety form. Check the child-safety rules if under-18s may use the app. Use the typed town, never device location.
- **Review access:** keep a test club ready for reviewers.

## Order of work

1. Backend migrations and `VERIFY_clubs.sql` (additive, safe to ship before any app).
2. Website `/c/[code]` page and the iOS association file.
3. iOS: tab enum refactor, Clubs tab, suggestions, sign-up step and tick-box; TestFlight.
4. Legal text and store forms, in step with the iOS release.
5. Android port: top-bar Profile and tab reorder first, then Clubs, including App Links.
6. Seed 10-20 real clubs by hand and ask existing users once for theirs.

## Open items

1. ~~Android navigation~~ **Decided:** move Profile to a top-bar avatar and give Clubs the fifth tab slot (see Components). Android's tab order also changes from Games, Remote, Friends, History to Games, Friends, Clubs, Remote, History, which matches iOS.
2. **Age tick-box:** placement agreed (the account-creation screen, replacing the passive "By continuing" text, gating the email, Google and Apple buttons). The exact screens per platform are confirmed in the plan.
3. ~~Sign-up club step mockup~~ Done (artboard 24).
4. **Friend-request cap** of 50 per 24 hours is a judgement; check against normal use after launch.
5. **Club pictures.** Clubs use a coloured circle with the first letter. No photos in v1.

## Testing

- SQL: `VERIFY_clubs.sql` covers create/join/leave, the 5-club limit, admin promotion, empty-club cleanup, account deletion, suggestion exclusions (friends, blocked, opted out, dismissed), the friend-request cap, and that non-members cannot read members.
- Unit tests: name normalisation and validation; suggestion row mapping; the request-cap error mapping (50); analytics event schema (as `AnalyticsEventsTest`).
- Manual, two or three test accounts on both platforms: create Open and Invite-only clubs, find, join, share and open a link with and without the app installed, suggestions appear and dismiss, report, leave as admin, delete an account that owns a club.

## Out of scope (v1)

Chat or messaging, club leaderboards, stats or club matches, club photos, several admins or moderators, join questions, a "request to join" mode, notifications for suggestions or new members, "clubs near me" by location, leagues, importing venue lists, showing clubs on the profile, renaming a club, an explicit delete-club button (a club disappears when empty).
