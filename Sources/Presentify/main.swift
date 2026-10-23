import AppKit
import PresentifyCore

let app = NSApplication.shared
let appController = PresentifyAppController()
app.delegate = appController
app.run()
