# Tomataton

A Pomodoro timer for macOS that you can use from the menu bar, a small window or the terminal.
It tracks focus and rest time per day and charts them by week.

## Install

You need macOS 15+, Xcode and XcodeGen (`brew install xcodegen`).

```sh
make install          # builds into /Applications and opens it
sudo make link-cli    # adds the `tomataton` command
```

Optional, both off by default, in Settings (⌘,): **Open at login**, and a **⌃⌥⌘P** shortcut that starts or pauses the timer from any app.

## Terminal

```sh
tomataton                    # status
tomataton start [preset]     # start or resume, e.g. `start deep --work 40`
tomataton pause | resume | toggle | skip | restart | stop
tomataton add 5m             # or -2m, 30s, 1h30m
tomataton rounds +1          # focus sessions before the long break
tomataton presets            # list, add, rm
tomataton stats [today|week]
```

`status`, `presets` and `stats` take `--json`. `tomataton status --short` prints `🍅 18:42` for a shell prompt.

## Develop

```sh
make run     # debug build, restarts the app
make test    # unit tests
```

Data lives in `~/Library/Application Support/Tomataton`.
