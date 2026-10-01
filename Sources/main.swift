import UIKit

// sendEvent: の到達をアプリ内で計数する(前回lldbで取った観測のアプリ内代替)。
// タッチのbegan/movedを別々に数え、画面のラベルへ通知する。
final class CountingApplication: UIApplication {
    static var tapCount = 0
    static var dragCount = 0
    override func sendEvent(_ event: UIEvent) {
        if event.type == .touches, let touches = event.allTouches {
            for t in touches {
                switch t.phase {
                case .began: CountingApplication.tapCount += 1
                case .moved: CountingApplication.dragCount += 1
                default: break
                }
            }
            NotificationCenter.default.post(name: .init("eventCounted"), object: nil)
        }
        super.sendEvent(event)
    }
}

_ = UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(CountingApplication.self),
    NSStringFromClass(AppDelegate.self)
)
