import Foundation
import MixinServices

struct DeviceTransferParticipant {
    
    let conversationId: String
    let userId: String
    let role: String
    let createdAt: String
    
    init(participant: Participant) {
        self.conversationId = participant.conversationId
        self.userId = participant.userId
        self.role = participant.role
        self.createdAt = participant.createdAt
    }
    
    func toParticipant() -> Participant {
        Participant(conversationId: conversationId,
                    userId: userId,
                    role: role,
                    status: ParticipantStatus.START.rawValue,
                    createdAt: createdAt)
    }
    
}

extension DeviceTransferParticipant: Codable {
    
    enum CodingKeys: String, CodingKey {
        case conversationId = "conversation_id"
        case userId = "user_id"
        case role
        case createdAt = "created_at"
    }
    
}
