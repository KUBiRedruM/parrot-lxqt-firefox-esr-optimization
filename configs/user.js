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
