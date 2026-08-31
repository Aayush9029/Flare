import Foundation

enum SingleInstanceLock {
    /// The descriptor is deliberately never closed: the kernel releases the flock at process exit.
    static func acquire() -> Bool {
        let path = NSTemporaryDirectory() + "ca.optimalapps.flare.lock"
        let descriptor = open(path, O_CREAT | O_RDWR, 0o644)
        guard descriptor != -1 else { return true }
        return flock(descriptor, LOCK_EX | LOCK_NB) == 0
    }
}
