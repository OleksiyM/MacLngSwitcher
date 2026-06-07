import Cocoa

// Отключаем буферизацию вывода
setbuf(stdout, nil)
setbuf(stderr, nil)

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate

// Запуск цикла событий Cocoa приложения
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
