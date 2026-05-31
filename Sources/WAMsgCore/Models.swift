import Foundation

public struct WhatsAppChat: Sendable, Equatable {
  public let id: Int64
  public let identifier: String
  public let name: String
  public let lastMessageAt: Date
  public let lastMessageText: String
  public let unreadCount: Int
  public let isArchived: Bool
  public let isRemoved: Bool
  public let isGroup: Bool
  public let sessionType: Int?

  public init(
    id: Int64,
    identifier: String,
    name: String,
    lastMessageAt: Date,
    lastMessageText: String,
    unreadCount: Int,
    isArchived: Bool,
    isRemoved: Bool,
    isGroup: Bool,
    sessionType: Int? = nil
  ) {
    self.id = id
    self.identifier = identifier
    self.name = name
    self.lastMessageAt = lastMessageAt
    self.lastMessageText = lastMessageText
    self.unreadCount = unreadCount
    self.isArchived = isArchived
    self.isRemoved = isRemoved
    self.isGroup = isGroup
    self.sessionType = sessionType
  }
}

public struct WhatsAppMessage: Sendable, Equatable {
  public let rowID: Int64
  public let chatID: Int64
  public let sender: String
  public let senderName: String?
  public let text: String
  public let date: Date
  public let isFromMe: Bool
  public let stanzaID: String
  public let fromJID: String?
  public let toJID: String?
  public let messageType: Int?
  public let messageStatus: Int?
  public let errorStatus: Int?
  public let attachmentsCount: Int

  public init(
    rowID: Int64,
    chatID: Int64,
    sender: String,
    senderName: String? = nil,
    text: String,
    date: Date,
    isFromMe: Bool,
    stanzaID: String,
    fromJID: String? = nil,
    toJID: String? = nil,
    messageType: Int? = nil,
    messageStatus: Int? = nil,
    errorStatus: Int? = nil,
    attachmentsCount: Int = 0
  ) {
    self.rowID = rowID
    self.chatID = chatID
    self.sender = sender
    self.senderName = senderName
    self.text = text
    self.date = date
    self.isFromMe = isFromMe
    self.stanzaID = stanzaID
    self.fromJID = fromJID
    self.toJID = toJID
    self.messageType = messageType
    self.messageStatus = messageStatus
    self.errorStatus = errorStatus
    self.attachmentsCount = attachmentsCount
  }
}

public struct WhatsAppAttachment: Sendable, Equatable {
  public let id: Int64
  public let messageID: Int64
  public let localPath: String
  public let thumbnailPath: String
  public let title: String
  public let vCardName: String
  public let fileSize: Int64
  public let mediaURL: String

  public init(
    id: Int64,
    messageID: Int64,
    localPath: String,
    thumbnailPath: String,
    title: String,
    vCardName: String,
    fileSize: Int64,
    mediaURL: String
  ) {
    self.id = id
    self.messageID = messageID
    self.localPath = localPath
    self.thumbnailPath = thumbnailPath
    self.title = title
    self.vCardName = vCardName
    self.fileSize = fileSize
    self.mediaURL = mediaURL
  }
}

