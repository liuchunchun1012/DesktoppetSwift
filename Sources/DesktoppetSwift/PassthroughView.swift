import SwiftUI
import AppKit

/// A hosting view that allows clicks on transparent areas to pass through,
/// The window is 220px tall, 300px wide
/// - Bottom ~130px: cat area
/// - Top ~90px: bubble area (when visible)
class PassthroughView<Content: View>: NSHostingView<Content> {
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard bounds.contains(point) else {
            return nil
        }
        
        // Full window is 300x220
        // Cat is 128px centered (x: 86-214) at bottom
        // Bubble is at top
        
        // Accept clicks in the entire visible area (let SwiftUI handle which component)
        // Only reject clicks in the absolute margins
        let margin: CGFloat = 30
        
        if point.x < margin || point.x > bounds.width - margin {
            return nil // Side margins - pass through
        }
        
        // Accept all clicks in the main content area
        return super.hitTest(point)
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        
        // Coordinates are flipped (Y=0 at top):
        // - Close button: top-left corner (~10-30, ~10-30)
        // - Bubble area: Y < 100 (top of window)
        // - Cat area: Y > 120 (bottom of window)
        
        // Check close button first (top-left corner)
        // Close button is at roughly X: 10-30, Y: 10-30 (flipped)
        let closeButtonMaxX: CGFloat = 35
        let closeButtonMaxY: CGFloat = 35
        
        if location.x < closeButtonMaxX && location.y < closeButtonMaxY {
            print("Close button clicked at (\(location.x), \(location.y))")
            NotificationCenter.default.post(name: .bubbleClose, object: nil)
            return // Don't pass through
        }
        
        // Cat area check
        let catMinY: CGFloat = 120
        let catMinX: CGFloat = 70
        let catMaxX: CGFloat = 230
        
        let inCatArea = location.y > catMinY && 
                        location.x >= catMinX && location.x <= catMaxX
        
        if inCatArea {
            print("Pet clicked at (\(location.x), \(location.y))")
            NotificationCenter.default.post(name: .petClicked, object: nil)
        }
        
        super.mouseDown(with: event)
    }
}

// Notification for pet click
extension Notification.Name {
    static let petClicked = Notification.Name("petClicked")
    static let bubbleClose = Notification.Name("bubbleClose")
}
