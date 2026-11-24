# Optimizing Firefox ESR & Fixing Window Persistence on Parrot OS (LXQt + Xfwm4)

A complete troubleshooting log and configuration guide for running **Firefox ESR** smoothly and fixing persistent window size/position resets on a 2014 **ASUS F553MA** (Intel Bay Trail CPU, 8 GB RAM) running **Parrot OS (LXQt)**.

---

## Hardware & Environment Specs
* **Device:** ASUS F553MA (2014, 64-bit Intel Celeron/Pentium Bay Trail)
* **RAM:** 8 GB (`7.6 GiB` usable)
* **OS:** Parrot OS (Debian-based, 64-bit)
* **Desktop Environment:** LXQt
* **Active Window Manager:** `xfwm4` (not Openbox)
* **Browser:** `firefox-esr` (WM_CLASS: `"Navigator", "firefox-esr"`)

---

## Part 1: Memory, Swap (zram), & Firefox ESR Performance

### 1. Firefox vs. Firefox ESR on Older Hardware
* **Finding:** Even though the laptop is from 2014, installing a modern 64-bit Linux distro (Parrot OS) means the system is **not** stuck on legacy OS cutoffs (like Windows 7/8's Firefox 115 ESR limit). Parrot OS ships with the current, actively patched **Firefox ESR** branch via APT.

### 2. Discovering Existing zram & Fixing `vm.swappiness`
* **Check:** Running `zramctl` and `swapon --show` revealed Parrot OS already had a **3.8 GB `lz4` zram swap device** (`/dev/zram0`, priority `100`) active with zero slow disk swap.
* **Problem:** `cat /proc/sys/vm/swappiness` returned **`10`**. While `10` protects physical SSDs/HDDs from excessive writes, it prevents Linux from proactively compressing inactive pages into RAM-based zram.
* **Solution:** Raised `vm.swappiness` to `150` so Linux utilizes fast compressed RAM swap when memory pressure rises:
  ```bash
  echo "vm.swappiness=150" | sudo tee /etc/sysctl.d/99-zram.conf && sudo sysctl -p /etc/sysctl.d/99-zram.conf
  ```
* **Load Test Result (`free -h` with multiple tabs open):** Confirmed 8 GB of total RAM (`5.3 GiB` available under load, `0B` swap needed), proving the hardware had plenty of headroom.

### 3. Firefox ESR `about:config` & Extension Tuning
* Installed **Auto Tab Discard** (with *"Consider idle state"* left unchecked so tabs unload on schedule rather than waiting for user inactivity).
* Applied lightweight `about:config` tweaks to reduce CPU/RAM overhead on the Bay Trail processor:
  * `browser.tabs.unloadOnLowMemory` = `true`
  * `network.prefetch-next` = `false`
  * `network.dns.disablePrefetch` = `true`
  * `network.http.speculative-parallel-limit` = `0`
  * `browser.sessionhistory.max_total_viewers` = `1`
  * `toolkit.cosmeticAnimations.enabled` = `false`

---

## Part 2: The Window Size & Position Dilemma (Full Troubleshooting Log)

**Goal:** Make Firefox ESR remember its exact split-screen left-half window size and position across restarts (`Ctrl + Q` and reopen).

### Attempt 1: Checking Firefox's Built-In Startup & UI Settings
* **What happened:** Checked **Open previous windows and tabs** under **Settings → Home and startup** (note: newer Firefox ESR moved this out of the main *General* page into its own *Home and startup* sidebar tab).
* **Result:** Firefox restored open tabs, **but completely ignored and reset the window size and screen position** on every restart.

### Attempt 2: Trying to Configure Openbox (`lxqt-rc.xml`)
* **Assumption:** Standard LXQt setups use Openbox as their window manager.
* **Errors Encountered:**
  * `cp: cannot stat '/home/kubi/.config/openbox/lxqt-rc.xml': No such file or directory`
  * `cp: cannot stat '/etc/xdg/openbox/rc.xml': No such file or directory`
* **Root Cause:** Checking active processes (`ps -e | grep -E 'openbox|xfwm4|kwin|marco'`) revealed Parrot OS LXQt was actually running **`xfwm4`** (XFCE's window manager), not Openbox. `xfwm4` does not support native per-application XML window rules.

### Attempt 3: External Window Positioning with `devilspie2` & `xwininfo`
* **What we tried:** Installed `devilspie2` and measured Firefox's coordinates using `xwininfo` (`X=1, Y=56, Width=964, Height=711`).
* **Errors & Glitches Encountered:**
  1. **Syntax Error:** Pasting placeholder variables triggered:
     `Error: /home/kubi/.config/devilspie2/firefox.lua:2: set_window_geometry: Four indata expected`
  2. **Titlebar Offset Bug (`~28px` / `0.5 cm` misalignment):** `xwininfo` measures the *inner* window content area (below the top panel + titlebar = `Y: 56`), whereas `devilspie2`'s `set_window_geometry()` positions the *outer* window frame (including the titlebar). This pushed Firefox downward by ~28 pixels, cutting off the bottom edge, and tweaking `Y` (`28` → `24` → `20`) and `Height` (`711` → `720`) created a frustrating game of pixel whack-a-mole.
* **Cleanup:** Removed `devilspie2` completely (`killall devilspie2 && rm -rf ~/.config/devilspie2`).

### Attempt 4: Native `xfwm4` Edge-Tiling
* **What we tried:** Enabled **"Automatically tile windows when moving toward the screen edge"** inside `xfwm4-tweaks-settings` → **Accessibility** (note: distinct from `lxqt-config-session`).
* **Result:** Snapping Firefox to the left edge worked cleanly during an active session, **but `xfwm4` treats tiled/snapped geometry as a temporary state** and does not save it as a permanent window dimension when the app closes.

---

## The Root Cause & Final Working Solution

### Why Firefox Kept Forgetting Its Window Size
1. **Parrot OS Privacy Hardening (`privacy.resistFingerprinting`):** Parrot OS enables `privacy.resistFingerprinting = true` by default in Firefox ESR to prevent screen-size browser fingerprinting. As a side effect, Firefox deliberately discards saved window dimensions (`xulstore.json`) and resets to a default window box every time it launches.
2. **Xfwm4 Tiled State vs. Manual Resize:** Xfwm4 only saves window geometry on exit if the window was manually resized rather than left in a temporary edge-tiled state.

### Step-by-Step Fix
1. Open Firefox ESR and navigate to **`about:config`** (accept the risk warning).
2. Search for **`privacy.resistFingerprinting`** and toggle it from `true` to **`false`**.
3. Manually drag/resize Firefox's window borders to the desired left-half position (rather than using temporary edge-tiling).
4. Close Firefox cleanly with **`Ctrl + Q`** so it writes the geometry to `xulstore.json`.
5. Reopen Firefox—it now restores the exact size and screen position permanently.
