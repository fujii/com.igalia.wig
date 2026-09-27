# com.igalia.wig

Flatpak manifest for [wig](https://github.com/Igalia/wig), a web browser built on WPE WebKit.

The manifest builds these modules from source: libevent, OpenXR SDK, WPE WebKit (`main`), wpe-platform-gtk, template-glib and wig.

## Requirements

- `flatpak` and `flatpak-builder`
- The Flathub remote:

  ```sh
  flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  ```

- The runtime, SDK and SDK extension used by the manifest:

  ```sh
  flatpak install --user flathub org.gnome.Platform//50 org.gnome.Sdk//50 org.freedesktop.Sdk.Extension.llvm22//25.08
  ```

  Alternatively, pass `--install-deps-from=flathub` to `flatpak-builder` to install them automatically.

Building WebKit takes a long time and needs a lot of memory and disk space.

## Building

```sh
./build.sh
```

This runs:

```sh
flatpak-builder --force-clean --user --install _build_$(date +%F) com.igalia.wig.yaml
```

It builds into a dated directory such as `_build_2026-09-27` and installs the result for the current user as `com.igalia.wig//master`.
The `wig`, WebKit and wpe-platform-gtk sources track their `main` branches, so every build picks up the latest commits.
The exact commits used by a build are recorded in `_build_<date>/files/manifest.json`.

## Running

```sh
flatpak run com.igalia.wig
```

Start it from a directory such as `~` or `/`.
WebKit spawns its web processes in a sub-sandbox with `flatpak-spawn --sandbox`, which uses the current working directory.
The sub-sandbox has no access to your home directory, so if you start wig from somewhere else inside it (for example `~/src/foo`), the sandbox check fails and WebKit silently runs the web processes without the sandbox ([bug 325395](https://bugs.webkit.org/show_bug.cgi?id=325395)).

### Running an older build

Don't use `flatpak-builder --run` with an old build directory.
WebKit's web processes are spawned via the Flatpak portal, and the portal starts them from the installed `master` instead of from the build directory.
If the two WebKit versions differ, the web processes crash with `Received invalid message`.

Instead, export the old build as its own branch and install that branch:

```sh
flatpak build-export --no-update-summary .flatpak-builder/cache _build_2026-09-21 main-2026-09-21
flatpak build-update-repo .flatpak-builder/cache
flatpak --user install wig-origin com.igalia.wig//main-2026-09-21
flatpak --user make-current com.igalia.wig master   # keep master as the default
flatpak run com.igalia.wig//main-2026-09-21
```

`wig-origin` is the local remote that `flatpak-builder --install` adds for `.flatpak-builder/cache`.

To remove it again:

```sh
flatpak --user uninstall com.igalia.wig//main-2026-09-21
ostree --repo=.flatpak-builder/cache refs --delete app/com.igalia.wig/x86_64/main-2026-09-21
flatpak build-update-repo .flatpak-builder/cache
```
