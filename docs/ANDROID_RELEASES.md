# Android development builds

The Android package ID is `com.layon.boardgamefighter`. Keep it unchanged so
Android recognizes future APKs as updates to the same app. Increment
`version/code` in `export_presets.cfg` for every published build.

## Local export

1. Install Godot's export templates for the same Godot version as the project.
2. Install JDK 17 and the Android SDK packages listed in Godot's Android export
   documentation, then set the Java SDK and Android SDK paths in Godot Editor
   Settings.
3. Copy `export_presets.cfg.example` to `export_presets.cfg`. That local file is
   ignored by Git so signing credentials can be kept out of the repository.
4. Export the `Android Debug` preset to `exports/BoardGameFighter-debug.apk`.

The debug APK is for sideloaded development builds. Keep the Android debug
keystore at `~/.android/debug.keystore`; builds signed with a different key
cannot update an existing installation. Back up that file privately if you
need to preserve update compatibility after reinstalling this computer.

## Sharing a build

Upload the APK as an asset on a GitHub Release in the private repository. People
need access to the private repository to download it. On Android, they can open
the APK and approve installation from their browser or file manager when
prompted. Replacing the APK in a release does not trigger an automatic update;
each new build must have a higher version code and be installed by the user.

This is a development distribution path. A separately managed release signing
key should be set up before distributing a long-lived release build. Never put
that key or its passwords in Git.
