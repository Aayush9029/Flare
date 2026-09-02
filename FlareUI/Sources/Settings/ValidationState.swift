import Foundation

enum ValidationState: Equatable {
    case idle
    case validating
    case success
    case failure(String)
}
