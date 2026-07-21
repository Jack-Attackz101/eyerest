//
//  main.swift
//  Iris
//
//  Program entry point. We deliberately avoid a SwiftUI `@main App` struct and
//  drive an AppKit application ourselves so Iris can live purely in the menu
//  bar (no Dock icon, no main window). `LSUIElement` in Info.plist plus the
//  `.accessory` activation policy keep it out of the Dock and app switcher.
//

import Cocoa

NSLog("Iris: main starting")
let application = NSApplication.shared
// Instantiating the delegate builds TimerEngine.shared (which touches
// SMAppService). Logging brackets that so an early crash is locatable.
NSLog("Iris: creating AppDelegate")
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
NSLog("Iris: delegate set, entering run loop")
application.run()
