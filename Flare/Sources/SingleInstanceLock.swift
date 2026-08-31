import Foundation

/// A second copy would register the same global hotkey and fight the first for it.
final class SingleInstanceLock {
    static let shared = SingleInstanceLock()

    private var descriptor: Int32 = -1

    private init() {}

    func acquire() -> Bool {
        let path = NSTemporaryDirectory() + "art.aayush.Flare.lock"
        descriptor = open(path, O_CREAT | O_RDWR, 0o644)
        guard descriptor != -1 else { return true }
        return flock(descriptor, LOCK_EX | LOCK_NB) == 0
    }
}
