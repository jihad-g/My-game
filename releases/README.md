# Shardlands builds

| File | Version | Platform |
|---|---|---|
| [Shardlands-v0.17.1-windows.zip](Shardlands-v0.17.1-windows.zip) | 0.17.1 (Milestone 17a - Heroes' Arsenal; the character faces the mouse) | Windows 10/11, 64-bit |

Older builds are in the git history of this folder (v0.16.0: commit 482c0c8, v0.13.0: commit d8a28b4, v0.12.0: commit 6a42fc1).

## Install on Windows

1. Click the zip above, then **Download raw file** (the download icon at the top right).
2. Right-click the downloaded zip → **Extract All...** → Extract.
3. Open the extracted `windows` folder and double-click **Shardlands.exe**.
4. If Windows says "Windows protected your PC": **More info** → **Run anyway**
   (the game is not code-signed yet).

Needs a graphics card with Vulkan support. Saves are kept in
`%APPDATA%\Godot\app_userdata\Shardlands\worlds` (with automatic backups - see *Recover* in the menu).

## Build it yourself

See [docs/RELEASE.md](../docs/RELEASE.md): `python3 tools/fetch_export_templates.py windows linux web`
then `tools/build_release.sh`.
