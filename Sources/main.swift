import Cocoa

// Disable output buffering
setbuf(stdout, nil)
setbuf(stderr, nil)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

// Start the Cocoa application event loop
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
