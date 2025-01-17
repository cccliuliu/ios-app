import Foundation

enum DeviceTransferDisplayState {
    
    case preparing
    case ready
    case connected
    case transporting(processedCount: Int, totalCount: Int)
    case failed(DeviceTransferConnectionClosedReason)
    case finished
    case closed
    
}
