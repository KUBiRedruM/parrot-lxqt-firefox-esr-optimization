#!/usr/bin/env bash
set -e

echo "=== Parrot OS (LXQt + Xfwm4) & Firefox ESR Optimization Script ==="

# 1. Optimize vm.swappiness for zram if zram is active
if swapon --show | grep -q "zram"; then
    echo "[+] Active zram detected. Setting vm.swappiness=150..."
    echo "vm.swappiness=150" | sudo tee /etc/sysctl.d/99-zram.conf > /dev/null
    sudo sysctl -p /etc/sysctl.d/99-zram.conf > /dev/null
    echo "[✓] vm.swappiness updated to 150."
else
    echo "[!] No active zram swap detected. Skipping sysctl swappiness tweak."
fi

# 2. Locate the default Firefox ESR profile directory
FF_DIR="$HOME/.mozilla/firefox"
if [ ! -d "$FF_DIR" ]; then
    echo "[!] Firefox profile folder not found. Launch Firefox ESR once first, then re-run this script."
    exit 1
fi

PROFILE_DIR=$(find "$FF_DIR" -maxdepth 1 -type d \( -name "*.default-esr" -o -name "*.default-release" \) | head -n 1)

if [ -z "$PROFILE_DIR" ]; then
    echo "[!] Could not find a default Firefox profile in $FF_DIR."
    exit 1
fi

# 3. Warn if Firefox is currently running
if pgrep -x "firefox-esr" > /dev/null || pgrep -x "firefox" > /dev/null; then
    echo "[!] Please close Firefox completely (Ctrl + Q) before running this script so settings aren't overwritten."
    exit 1
fi

# 4. Write user.js optimizations into the Firefox profile
echo "[+] Applying Firefox ESR optimizations to: $PROFILE_DIR"
cat << 'EOF' > "$PROFILE_DIR/user.js"
// Allow Firefox to remember custom window size and position across restarts
user_pref("privacy.resistFingerprinting", false);

// Unload tabs automatically under low memory
user_pref("browser.tabs.unloadOnLowMemory", true);

// Reduce background prefetching and RAM overhead on older CPUs
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.speculative-parallel-limit", 0);
user_pref("browser.sessionhistory.max_total_viewers", 1);
user_pref("toolkit.cosmeticAnimations.enabled", false);
EOF

echo "[✓] Done! Launch Firefox ESR, manually resize the window to your preferred spot, and close with Ctrl + Q once to lock it in."
