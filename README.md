# Tony's Snes9x macOS Build
*Snes9x - Portable Super Nintendo Entertainment System (TM) emulator*

This is a macOS-focused customization of Snes9x, based on the
[upstream Snes9x project](https://github.com/snes9xgit/snes9x). It is not the
official Snes9x repository.

Please check the [Wiki](https://github.com/snes9xgit/snes9x/wiki) for additional information.

## macOS quality-of-life improvements

- **Menus during gameplay:** use the menus without first clicking the game to
  pause emulation.
- **Live settings and cheat windows:** keep Preferences, Cheats, and Cheat Finder
  open while the game continues running. Individual edits and memory snapshots
  synchronize safely with emulation and preserve any manual pause.
- **Click-to-toggle pause:** click the game to pause, then click again to resume.
  Mouse and light-gun controllers retain their normal game-input behavior.
- **Pause/Resume menu command:** the Emulation menu reflects the current pause
  state and lets you toggle it.
- **Mute Audio:** toggle audio from the Emulation menu without stopping gameplay,
  with a checkmark showing the mute state.
- **Working Open Recent:** successfully opened ROMs are saved in a deduplicated
  history, can be reopened directly, and can be removed with Clear Menu.
- **Live Cheat Finder snapshots:** Reload, Store, and Search capture current RAM
  without requiring you to pause the game manually.
- **Updated video settings:** removed the obsolete "* Requires restart" label.
- **Input and safety fixes:** clear held keyboard input when the game loses focus,
  preserve rapid edit order, and reject stale edits after changing games.

The renderer remains Metal. Integer window-size presets, a stats strip, and an
in-app fullscreen menu bar are not implemented yet.

## Building on macOS

With Xcode and its macOS SDK installed, run from the repository root:

```sh
xcodebuild -project macosx/snes9x.xcodeproj -scheme snes9x \
  -configuration Release -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO build
```

This builds locally without the upstream Developer ID signing certificate.
Xcode prints the output location for `Snes9x.app`; the default location is under
its DerivedData directory.

## macOS menus

Menus, Preferences, Cheats, and Cheat Finder remain available during gameplay.
Browsing menus or keeping these windows open does not pause emulation.
Individual settings changes, cheat edits, and memory snapshots briefly suspend
emulation at a safe emulation-loop boundary, then resume automatically without
changing a manual pause. Cheat Finder's Reload and Search actions capture fresh
RAM snapshots while gameplay continues. The Emulation menu's Pause/Resume command
controls the manual pause.
Clicking the game view also toggles pause/resume, except when the selected SNES
controller uses the mouse or a light gun. Emulation > Mute Audio toggles sound
without pausing gameplay; its checkmark reflects the current state. Mute is kept
when loading another game during the same app session.
File > Open Recent lists successfully opened ROMs, most recent first, and reopens
them directly in the emulator. Clear Menu removes this history.

Reset, controller-device changes, and enabling or disabling cheats briefly
suspend emulation while the action runs, preserving the manual pause state.
If the save-state slot selector is open, finish or cancel it before an action
that requires access to emulator state can proceed.

On macOS, run `bash macosx/tests/run-menu-tests.sh` to build and exercise menu
validation, live editor windows, synchronized edits and snapshots, manual pause
preservation, ROM replacement, and shutdown using a generated test ROM (no game
download required).

## Upstream nightly builds

These are upstream Snes9x builds, not builds of this repository's macOS changes:

### snes9x

| OS            | status                                           |
|---------------|--------------------------------------------------|
| Windows       | [![Status][s9x-win-all]][appveyor]               |
| Linux (GTK)   | [![Status][snes9x_linux-gtk-amd64]][cirrus-ci]   |
| Linux (X11)   | [![Status][snes9x_linux-x11-amd64]][cirrus-ci]   |
| FreeBSD (X11) | [![Status][snes9x_freebsd-x11-amd64]][cirrus-ci] |
| macOS         | [![Status][snes9x_macOS-amd64]][cirrus-ci]       |

[appveyor]: https://ci.appveyor.com/project/snes9x/snes9x
[cirrus-ci]: http://cirrus-ci.com/github/snes9xgit/snes9x

[s9x-win-all]: https://ci.appveyor.com/api/projects/status/github/snes9xgit/snes9x?branch=master&svg=true
[snes9x_linux-gtk-amd64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=snes9x_linux-gtk-amd64
[snes9x_linux-x11-amd64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=snes9x_linux-x11-amd64
[snes9x_freebsd-x11-amd64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=snes9x_freebsd-x11-amd64
[snes9x_macOS-amd64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=snes9x_macOS-amd64

### libretro core

| OS                  | status                                                  |
|---------------------|---------------------------------------------------------|
| Linux/amd64         | [![Status][libretro_linux-amd64]][cirrus-ci]            |
| Linux/i386          | [![Status][libretro_linux-i386]][cirrus-ci]             |
| Linux/armhf         | [![Status][libretro_linux-armhf]][cirrus-ci]            |
| Linux/armv7-neon-hf | [![Status][libretro_linux-armv7-neon-hf]][cirrus-ci]    |
| Linux/arm64         | [![Status][libretro_linux-arm64]][cirrus-ci]            |
| Android/arm         | [![Status][libretro_android-arm]][cirrus-ci]            |
| Android/arm64       | [![Status][libretro_android-arm64]][cirrus-ci]          |
| Emscripten          | [![Status][libretro_emscripten]][cirrus-ci]             |
| macOS/amd64         | [![Status][libretro_macOS-amd64]][cirrus-ci]            |
| Nintendo Wii        | [![Status][libretro_nintendo-wii]][cirrus-ci]           |
| Nintendo Switch     | [![Status][libretro_nintendo-switch-libnx]][cirrus-ci]  |
| Nintendo GameCube   | [![Status][libretro_nintendo-ngc]][cirrus-ci]           |
| PSP                 | [![Status][libretro_playstation-psp]][cirrus-ci]        |

[libretro_linux-amd64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_linux-amd64
[libretro_linux-i386]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_linux-i386
[libretro_linux-armhf]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_linux-armhf
[libretro_linux-armv7-neon-hf]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_linux-armv7-neon-hf
[libretro_linux-arm64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_linux-arm64
[libretro_android-arm]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_android-arm
[libretro_android-arm64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_android-arm64
[libretro_emscripten]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_emscripten
[libretro_macOS-amd64]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_macOS-amd64
[libretro_nintendo-wii]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_nintendo-wii
[libretro_nintendo-switch-libnx]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_nintendo-switch-libnx
[libretro_nintendo-ngc]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_nintendo-ngc
[libretro_playstation-psp]: https://api.cirrus-ci.com/github/snes9xgit/snes9x.svg?task=libretro_playstation-psp
