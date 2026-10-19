# Shardlands builds

| File | Version | Platform |
|---|---|---|
| [Shardlands-v0.44.0-windows.zip](Shardlands-v0.44.0-windows.zip) | 0.44.0 (Milestone 36: Performance) | Windows 10/11, 64-bit |

Older builds are in the git history of this folder (v0.43.0: commit 150d015, v0.42.1: commit c759a3b, v0.42.0: commit f1d2972, v0.41.0: commit b1163e3, v0.40.0: commit 5638502, v0.39.0: commit 6d1321e, v0.38.0: commit 8d622b5, v0.37.0: commit fcb0185, v0.36.0: commit 4c3ec9d, v0.35.0: commit ae33813, v0.34.0: commit 6aff896, v0.33.0: commit 6ed1aea, v0.32.0: commit 75bc29d, v0.31.0: commit 47b214c, v0.30.0: commit 0626803, v0.29.0: commit f4875bc, v0.28.0: commit 3a89950, v0.27.0: commit 13b28ee, v0.26.0: commit 712ee91, v0.25.1: commit f0192c6, v0.25.0: commit 31df5a1, v0.24.0: commit 9eaed18, v0.23.1: commit 311413e, v0.23.0: commit d91a552, v0.22.0: commit 537925d, v0.21.0: commit d113f78, v0.20.0: commit 520386f, v0.19.0: commit 8ea33dd, v0.18.0: commit 4bc7d38, v0.17.1: commit 0042754, v0.16.0: commit 482c0c8, v0.13.0: commit d8a28b4, v0.12.0: commit 6a42fc1).

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
