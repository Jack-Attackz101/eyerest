//
//  main.swift
//  EyeRest
//
//  Program entry point. We deliberately avoid a SwiftUI `@main App` struct and
//  drive an AppKit application ourselves so EyeRest can live purely in the menu
//  bar (no Dock icon, no main window). `LSUIElement` in Info.plist plus the
//  `.accessory` activation policy keep it out of the Dock and app switcher.
//

import Cocoa

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
