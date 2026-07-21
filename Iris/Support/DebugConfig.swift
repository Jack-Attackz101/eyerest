//
//  DebugConfig.swift
//  Iris
//
//  Development-only switches. Kept in one place so they're easy to find and
//  flip off before shipping.
//

enum DebugConfig {

    /// When true, the timer treats every "minute" as a single second, so a full
    /// cycle (count → warning → rest → reset) runs in seconds instead of minutes.
    /// With this on, `intervalMinutes = 20` means 20 seconds and
    /// `warningMinutes = 2` means 2 seconds. Rest duration is already in seconds
    /// and is unaffected.
    ///
    /// ⚠️ SHIPPING: flip this to `false`. It is *also* force-disabled in Release
    /// builds below, so a stray `true` can never reach production — but keep it
    /// tidy anyway.
    private static let fastCycleRequested = false

    /// The effective flag. Always `false` outside of Debug builds.
    static var fastCycle: Bool {
        #if DEBUG
        return fastCycleRequested
        #else
        return false
        #endif
    }
}
