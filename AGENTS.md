# Testing notes

- wig is a single-instance GApplication.
  `flatpak run com.igalia.wig//<branch>` is forwarded to an already running instance, even of another branch, so the new build never runs.
  Check with `flatpak ps --columns=application,branch,pid` and quit the running wig first.
  Before reporting a test result, confirm which branch is running.
- The same applies to the Wig MCP (`flatpak run com.igalia.wig//<branch> --mcp-stdio`): it cannot connect to an already running wig and gets no response.
  Quit the running wig first so that `--mcp-stdio` starts a fresh one.
- wig stores its GSettings in a keyfile, `~/.var/app/com.igalia.wig/config/com.igalia.wig/settings.ini`, not in dconf.
  `flatpak run --command=gsettings` reads another backend, so it shows schema defaults instead of the real values and its `set` has no effect on wig.
  Read and edit `settings.ini` directly, or use the `wig:settings/` pages.
  For example, the Wig MCP needs `enable-mcp=true` there.
