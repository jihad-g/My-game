# Releasing Shardlands

How to build, test and ship a release (Milestone 13).

## 1. Test

```bash
tools/run_tests.sh                                              # full suite (~5 min)
godot --headless --path . res://tools/playthrough.tscn -- --class=wizard   # bot plays the loop
godot --headless --path . res://tools/stress_test.tscn          # 20 seeds + benchmarks -> docs/PERFORMANCE.md
godot --headless --path . res://tools/balance_report.tscn       # -> docs/BALANCE.md
```

## 2. Build

```bash
python3 tools/fetch_export_templates.py windows linux web   # once per Godot version (~260 MB, not the 1.2 GB pack)
tools/build_release.sh                                       # or: tools/build_release.sh windows
```

Output in `build/release/`:

| File | What |
|---|---|
| `Shardlands-v<version>-windows.zip` | one `Shardlands.exe` with the game embedded + README |
| `Shardlands-v<version>-linux.tar.gz` | `Shardlands.x86_64` + README |
| `web/` | browser build: `shardlands.html` launcher, engine in < 15 MB parts, game data |

The exports leave out `tests/`, `tools/`, `docs/`, `platform/` and `releases/`, and keep the
blueprint `.json` files the game reads.

Not done yet: code signing (Windows SmartScreen shows "Windows protected your PC" until the .exe is
signed with a code-signing certificate), a macOS build (needs signing and notarization), an installer.

## 3. Steam

The game talks to Steam only through `Platform` → `SteamBackend`, which uses the
[GodotSteam](https://godotsteam.com) GDExtension. It is not in this repository (the Steamworks SDK
licence doesn't allow redistributing it here).

1. Create the app on Steamworks; note the **app id** and the **depot ids** (Windows, Linux).
2. Install GodotSteam (GDExtension build for Godot 4.4) into `addons/godotsteam/`.
3. Set **Project Settings → shardlands/platform/steam_app_id** to the app id. For local testing you can
   also put a `steam_appid.txt` next to the game (`platform/steam/steam_appid.txt.example` uses 480,
   Valve's test app).
4. Run `godot --headless --path . -s tools/export_steam_config.gd` and enter
   `platform/steam/achievements.csv` and `stats.csv` under *Stats & Achievements* (the API names must
   match). Upload `rich_presence.vdf` under *Rich Presence localization*. Achievement icons still need
   to be drawn.
5. **Steam Cloud**: use Auto-Cloud with root `WinAppDataRoaming`, subdirectory
   `Godot/app_userdata/Shardlands/worlds`, pattern `*` (Linux: `LinuxHome`,
   `.local/share/godot/app_userdata/Shardlands/worlds`). Settings and the profile live one folder up and
   can be added the same way.
6. Edit the ids in `platform/steam/app_build.vdf` and the two `depot_build_*.vdf` files, run
   `tools/build_release.sh windows linux`, then upload:
   `steamcmd +login <builder> +run_app_build <path>/platform/steam/app_build.vdf +quit`.

When GodotSteam is installed and the app id is set, the game reports achievements and stats to Steam,
shows "Level 12 Knight · Whispering Forest" as rich presence, and pauses single-player games while the
overlay is open. Start with `-- --no-steam` to force the local platform. Achievements earned before Steam
was available are sent on the next start (they are always kept in the player profile).

## 4. Where players' files live

| | Windows | Linux |
|---|---|---|
| Worlds, backups | `%APPDATA%\Godot\app_userdata\Shardlands\worlds\` | `~/.local/share/godot/app_userdata/Shardlands/worlds/` |
| Settings, profile (tutorial, achievements) | `...\Shardlands\settings.cfg`, `profile.cfg` | same folder |
| Logs, crash reports | `...\Shardlands\logs\`, `crash_reports\` | same folder |

Ask testers for the newest folder in `crash_reports/` when something goes wrong: it holds
`report.txt` (session and system) and `log_tail.txt` (the end of the log).
