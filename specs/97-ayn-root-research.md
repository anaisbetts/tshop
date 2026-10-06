# 97 — AYN Thor "Run anything as root" research

Research into how [Thor-Wayfinder/thor-wayfinder](https://github.com/Thor-Wayfinder/thor-wayfinder) exploits the AYN Thor's "Run Script as Root" mechanism. Cloned and read September 2026.

## TL;DR

The AYN Thor firmware ships a **root-owned binder daemon ("pservice") that any app can call, with no permission check** — it's the backend of the firmware's Settings → Thor → "Run Script as Root" feature. Wayfinder talks to that binder directly (reflection + raw `Parcel` transact) and gets **full root shell execution with zero setup**: no Magisk, no Shizuku, no ADB, no PC. It works because AYN ships the device **SELinux Permissive** ("Force SELinux" off, the default), so the normally-restricted `service_manager find` + `binder call` path from `untrusted_app` is not denied.

Wayfinder treats this as the *primary* root backend and layers fallbacks under it:

```
pservice (AYN stock, zero setup)  →  su (Magisk-rooted device)  →  Shizuku  →  trampoline/Intent hacks
```

## The mechanism, in Wayfinder's own words

`app/src/main/java/app/wayfinder/PServiceBridge.kt` (the whole trick, ~150 lines):

> Bridge to AYN's own root daemon "pservice" (uid 0, running from boot), which registers the binder service "PServerBinder" and executes shell commands as root via popen. This is the backend of the firmware's Settings → Thor → "Run Script as Root" feature (client in com.odin.settings, log tag "PServiceBridgeV2").
>
> On this firmware our app's domain (untrusted_app) can reach it — verified on device: `id` returns uid=0(root).

### Transaction contract

Reverse-engineered from the decompiled stock settings client (`com.odin.settings`, class `b1.C0182b`):

```kotlin
val binder = ServiceManager.getService("PServerBinder")   // via reflection, ServiceManager is @hide
data.writeStringArray(arrayOf(cmd, "0"))                  // [command, "0"], NO interface token
binder.transact(0, data, reply, 0)                        // code 0 = exec
val stdout = String(reply.createByteArray()!!)            // reply = raw bytes of stdout
```

That's it. Code `0`, a two-element string array, no interface-token check, stdout returned as a byte array. The daemon internally `popen()`s the string as root.

### Why it's reachable

- The daemon is registered in the global service registry at boot and **enforces no caller permission and no signature check**.
- SELinux is **Permissive** on stock firmware (AYN's own root-script feature requires it), so `untrusted_app` is allowed to find and transact with the service.
- Wayfinder's `SECURITY.md` is blunt about the consequence: *"The Thor's system service is open to every app on the device — that's AYN's design, not Wayfinder's, and Wayfinder doesn't make it wider."* Any app on a stock Thor is de-facto root.

### Availability probing (`isAvailable`)

- Probe = `exec("id")?.contains("uid=0")`.
- **Only success is cached.** A failed probe at boot (pservice not up yet) is retried on later calls (10 s backoff via `lastFail`), because an early failure used to disable root features until app restart. Re-checked per boot so the app auto-adapts if someone flips SELinux to Enforcing or the daemon is missing on another firmware.

## Known quirks (hard-won, all documented in comments)

These are the most transferable findings — the pservice interface is dumber than a shell:

1. **Only the FIRST line of output is returned.** Long multi-line results get lost.
2. **Long commands are silently dropped** (~300+ chars — e.g. a keep-list made a "Clear" call come back empty, which looked like failure).
3. **Inline shell operators are unreliable.** Redirects, `&`, trailing `sleep` in an inline command string "return instantly having done nothing".

**Workaround for all three: write a script file to `cacheDir`, run `sh <path>` as a plain two-token command.** pservice runs `sh <file>` faithfully and the script's operators work normally. Wayfinder's `runEntryPoint` does exactly this, one file per call (two threads reusing one script file raced: "a brightness read could come back with the other screen's level"), and terminates the tool's output with `| grep -m1 -E '^(OK|ERR)'` to fit the one-line reply.

1. **Serialize execs.** Overlapping transactions came back empty (`execLock` mutex around every transact).
2. **`pkill -f` self-matches.** `pkill -f app.wayfinder.InputMonitorTool` from inside pservice kills the pservice shell's *own* cmdline, "intermittently leaves the pservice binder in a bad state that silently drops the very next transact."

## Running Java entry points as root: the `app_process` pattern

Same trick Shizuku uses, but spawned per-call instead of a persistent daemon:

```
CLASSPATH=<apk> app_process /system/bin app.wayfinder.<Tool> <args…>
```

- Runs the app's own classes in a **bare root VM**, not an app process — so **ART hidden-API enforcement doesn't apply** and reflection into framework internals resolves freely (same as the `am` binary).
- `RootMover`: calls `IActivityTaskManager.moveRootTaskToDisplay` directly over binder — a call `am` exposes no CLI for. Reparents a live task across the Thor's two displays *without relaunch* (state preserved, no duplicate instances). Contract: stdout `OK <taskId>` / `ERR <reason>` + exit code; caller falls back to `am start` / trampoline on failure.
- `RecentsTool`, `InputMonitorTool`, `DisplayPowerTool` etc. follow the same shape.

### Persistent root helper

`InputMonitor.kt` spawns a long-lived root input helper via pservice, with two launch subtleties documented at length:

- Launch through a **script file** (see quirk 3), backgrounded with `&`, and **append `sleep 1`**: pservice reaps (`pclose`) the launcher shell when it returns, so a bare `&` kills the just-forked `app_process` before it detaches. The sleep keeps the shell alive long enough for the child to reparent to init. `setsid` breaks `app_process` — don't use it.
- **Unquoted `CLASSPATH=`** — single-quoting it stopped `app_process` from starting (the APK path has no spaces).
- The helper talks back over a `LocalServerSocket`, with uid identity checks on both ends and a handshake (a root process could impersonate, but gains nothing it didn't already have). The helper self-terminates (`Runtime.halt`) when the socket dies.

## What root is used for

Wide — grep of `PServiceBridge.exec(...)` call sites shows commands like:

- **Task/display moves**: `am start --display <id> -n <comp>`, `am force-stop`, home-on-display, plus the binder `moveRootTaskToDisplay` path.
- **AYN-vendor state**: `settings put system fan_mode …`, `setprop persist.vendor.debug.mode …` (perf profiles), `settings put system global_gamepad_to_mouse_mode …`, `settings put system dual_screen_display_mode …`, `cat /sys/class/drm/card0-DSI-2/dpms` (lid/screen power), `am broadcast -a action.tcc.button.key.event -p com.odin.dualscreen.assistant`.
- **System plumbing that needs root or a shell uid**: `settings put global device_provisioned 1`, `pm grant … POST_NOTIFICATIONS`, `appops set … SCHEDULE_EXACT_ALARM allow`, `cmd deviceidle whitelist +<pkg>`, `cmd wifi`/`cmd bluetooth_manager`, `cmd notification set_dnd`, `ime enable/set`, `service call SurfaceFlinger 1022 f <w>` (saturation), `screencap -d <display>` + `chown`, backgrounded `screenrecord`, `dumpsys activity/window/input/media_session/SurfaceFlinger` queries (focused app, per-display top task, media sessions).

## Fallback chain

`ForegroundAppService.kt` picks a backend per operation, in order:

1. **`PServiceBridge`** — stock Thor, zero setup.
2. **`RootHelper`** (`su -c …`) — only on Magisk-rooted devices; probe is `su -c id` containing `uid=0`, with a 20 s timeout because the first-ever `su` call pops the Magisk grant dialog. Same `runEntryPoint`/`moveTaskViaBinder` API as pservice.
3. **Shizuku** — binder API, needs companion app + per-boot restart dance.
4. **Trampoline activities / plain Intents** — lossy (relaunch, duplicates), last resort.

Only *successes* are cached for the probes; failures retry (same lesson as pservice).

## Security posture (Wayfinder's own review, SECURITY.md)

- Every string reaching a root command is **validated and shell-quoted** — a fixed command-injection path through an app-supplied package name, plus an activity-name injection in `am start`. Package names go through `Shell.isPkg`/`Shell.q`/`Shell.component` before interpolation.
- The stock service being open to all apps is called out as a **known limit, not their attack surface expansion** — on a stock Thor, any app already has root-equivalent power.
- Note the flip side: because *any* app can run arbitrary commands as root, Wayfinder's helper-socket identity check is mostly theater against a malicious root process ("gains nothing it didn't already have").

## Takeaways for us

1. **Vendor backdoors are real and reusable.** AYN exposed a root-exec binder with no caller check for their own settings feature; a third-party app reverse-engineered the transaction from the decompiled client and got root with zero user setup. If a device has a first-party "run script as root" toggle, the service behind it is worth a `service list` + Frida/jadx session.
2. **SELinux mode is the whole ballgame.** The trick is Permissive-only; probe (`id` → `uid=0`) at runtime, cache only successes, re-probe per boot, and design fallbacks for Enforcing.
3. **`app_process` + your own APK on CLASSPATH** is the cheap way to make privileged *binder* calls (not just shell commands) without any daemon — no hidden-API restrictions, one call then exit.
4. **Document the interface's lies.** One-line replies, silently dropped long commands, broken inline operators, self-killing `pkill`, serialized transacts — every one of these is a silent-failure class that would eat days without the comments Wayfinder left. Script-file indirection (`sh <file>`) is a robust universal workaround for flaky command-string executors.
