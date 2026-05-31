import Foundation
import WAMsgCore

struct ChatPayload: Encodable, Equatable {
  let id: Int64
  let identifier: String
  let name: String
  let lastMessageAt: String
  let lastMessageText: String
  let unreadCount: Int
  let isArchived: Bool
  let isRemoved: Bool
  let isGroup: Bool
  let sessionType: Int?
  let participants: [String]

  init(chat: WhatsAppChat, participants: [String] = []) {
    self.id = chat.id
    self.identifier = chat.identifier
    self.name = chat.name
    self.lastMessageAt = CLIISO8601.format(chat.lastMessageAt)
    self.lastMessageText = chat.lastMessageText
    self.unreadCount = chat.unreadCount
    self.isArchived = chat.isArchived
    self.isRemoved = chat.isRemoved
    self.isGroup = chat.isGroup
    self.sessionType = chat.sessionType
    self.participants = participants
  }
}

struct MessagePayload: Encodable, Equatable {
  let rowID: Int64
  let chatID: Int64
  let sender: String
  let senderName: String?
  let text: String
  let date: String
  let isFromMe: Bool
  let stanzaID: String
  let fromJID: String?
  let toJID: String?
  let messageType: Int?
  let messageStatus: Int?
  let errorStatus: Int?
  let attachmentsCount: Int
  let attachments: [AttachmentPayload]?

  init(message: WhatsAppMessage, attachments: [WhatsAppAttachment]? = nil) {
    self.rowID = message.rowID
    self.chatID = message.chatID
    self.sender = message.sender
    self.senderName = message.senderName
    self.text = message.text
    self.date = CLIISO8601.format(message.date)
    self.isFromMe = message.isFromMe
    self.stanzaID = message.stanzaID
    self.fromJID = message.fromJID
    self.toJID = message.toJID
    self.messageType = message.messageType
    self.messageStatus = message.messageStatus
    self.errorStatus = message.errorStatus
    self.attachmentsCount = message.attachmentsCount
    self.attachments = attachments?.map(AttachmentPayload.init)
  }
}

struct AttachmentPayload: Encodable, Equatable {
  let id: Int64
  let messageID: Int64
  let localPath: String
  let thumbnailPath: String
  let title: String
  let vCardName: String
  let fileSize: Int64
  let mediaURL: String

  init(attachment: WhatsAppAttachment) {
    self.id = attachment.id
    self.messageID = attachment.messageID
    self.localPath = attachment.localPath
    self.thumbnailPath = attachment.thumbnailPath
    self.title = attachment.title
    self.vCardName = attachment.vCardName
    self.fileSize = attachment.fileSize
    self.mediaURL = attachment.mediaURL
  }
}

struct SendPayload: Encodable, Equatable {
  let ok: Bool
  let recipient: String
  let text: String
  let sentMessage: MessagePayload?
}

struct StatusPayload: Encodable, Equatable {
  let databasePath: String
  let databaseReadable: Bool
  let databaseError: String?
  let whatsAppRunning: Bool?
  let automationError: String?
}

