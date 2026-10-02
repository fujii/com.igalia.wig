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
flatpak-builder --force-clean --user --install --default-branch=main-$(date +%F) _build com.igalia.wig.yaml
```

It builds in `_build` and installs the result for the current user as a dated branch such as `com.igalia.wig//main-2026-09-27`.
The newly installed branch becomes the current one, so `flatpak run com.igalia.wig` runs the latest build.
The `wig`, WebKit and wpe-platform-gtk sources track their `main` branches, so every build picks up the latest commits.
`_build` is overwritten by every build, but each build is kept as its branch in the local repository `.flatpak-builder/cache`.
The exact commits used by a build are recorded in `files/manifest.json`:

```sh
ostree --repo=.flatpak-builder/cache cat app/com.igalia.wig/x86_64/main-2026-09-27 /files/manifest.json
```

## Running

```sh
flatpak run com.igalia.wig
```

Start it from a directory such as `~` or `/`.
WebKit spawns its web processes in a sub-sandbox with `flatpak-spawn --sandbox`, which uses the current working directory.
The sub-sandbox has no access to your home directory, so if you start wig from somewhere else inside it (for example `~/src/foo`), the sandbox check fails and WebKit silently runs the web processes without the sandbox ([bug 325395](https://bugs.webkit.org/show_bug.cgi?id=325395)).

### Running an older build

Each build stays installed as its own branch, so you can run an older one by naming its branch:

```sh
flatpak --user list --app | grep com.igalia.wig   # list the installed builds
flatpak run com.igalia.wig//main-2026-09-21
```

To change which build `flatpak run com.igalia.wig` starts:

```sh
flatpak --user make-current com.igalia.wig main-2026-09-21
```

Don't use `flatpak-builder --run` with an old build directory.
WebKit's web processes are spawned via the Flatpak portal, and the portal starts them from the installed app instead of from the build directory.
If the two WebKit versions differ, the web processes crash with `Received invalid message`.

### Uninstalling a build

```sh
flatpak --user uninstall com.igalia.wig//main-2026-09-21
```

This only removes the installed app.
The build is still in the local repository `.flatpak-builder/cache`, so you can install it again later.

### Reinstalling an uninstalled build

Install it from `.flatpak-builder/cache`:

```sh
flatpak --user install wig-origin com.igalia.wig//main-2026-09-21
```

`wig-origin` is the local remote that `flatpak-builder --install` adds for `.flatpak-builder/cache`.
Flatpak removes it automatically when the last build installed from it is uninstalled.
In that case, add it again first:

```sh
flatpak --user remote-add --no-gpg-verify wig-origin .flatpak-builder/cache
```

To list the branches in `.flatpak-builder/cache`, run:

```sh
ostree --repo=.flatpak-builder/cache refs | grep ^app/com.igalia.wig/
```

### Removing a build completely

To also free the disk space, delete the branch from `.flatpak-builder/cache`:

```sh
flatpak --user uninstall com.igalia.wig//main-2026-09-21
ostree --repo=.flatpak-builder/cache refs --delete app/com.igalia.wig/x86_64/main-2026-09-21
flatpak build-update-repo --prune .flatpak-builder/cache
```

After this, the build can't be reinstalled.
