import Foundation

extension NSPoint {
    /// Get distance between this point and some other point
    public func distance(from point: NSPoint) -> CGFloat {
        func square(_ x: CGFloat) -> CGFloat {
            return x * x
        }

        return sqrt(square(x - point.x) + square(y - point.y))
    }
}
