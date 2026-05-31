import Foundation
import SQLite
import Testing
@testable import WAMsgCore

@Test
func listChatsOrdersByRecentActiveSessions() throws {
  let store = try makeFixtureStore()
  let chats = try store.listChats(limit: 10)

  #expect(chats.map(\.id) == [2, 1])
  #expect(chats[0].name == "Team Chat")
  #expect(chats[0].isGroup)
  #expect(chats[1].unreadCount == 2)
}

@Test
func messagesDecodeDirectionSendersAndAttachments() throws {
  let store = try makeFixtureStore()
  let messages = try store.messages(chatID: 1, limit: 10)

  #expect(messages.map(\.rowID) == [2, 1])
  #expect(messages[0].isFromMe)
  #expect(messages[0].sender == "me")
  #expect(messages[1].sender == "+15550001111@s.whatsapp.net")
  #expect(messages[1].senderName == "Ada")
  #expect(messages[1].attachmentsCount == 1)

  let attachments = try store.attachments(for: 1)
  #expect(attachments.count == 1)
  #expect(attachments[0].localPath == "/tmp/photo.jpg")
  #expect(attachments[0].fileSize == 42)
}

@Test
func messageFilteringUsesParticipantAndDateRange() throws {
  let store = try makeFixtureStore()
  let start = Date(timeIntervalSince1970: 1_700_000_005)
  let end = Date(timeIntervalSince1970: 1_700_000_030)
  let filter = WhatsAppMessageFilter(
    participants: ["me"],
    startDate: start,
    endDate: end
  )

  let messages = try store.messages(chatID: 1, limit: 10, filter: filter)
  #expect(messages.map(\.text) == ["reply"])
}

@Test
func messagesAfterReturnsRowsInAscendingOrder() throws {
  let store = try makeFixtureStore()
  let messages = try store.messagesAfter(afterRowID: 1, chatID: nil, limit: 10)

  #expect(messages.map(\.rowID) == [2, 3])
}

@Test
func participantsReturnsUniqueActiveMembers() throws {
  let store = try makeFixtureStore()
  let participants = try store.participants(chatID: 2)

  #expect(participants == ["+15550002222@s.whatsapp.net"])
}

@Test
func invalidDatabaseIsRejected() throws {
  let db = try Connection(.inMemory)

  #expect(throws: WAMsgError.invalidDatabase(path: ":memory:", reason: "expected ZWACHATSESSION and ZWAMESSAGE tables")) {
    _ = try WhatsAppStore(connection: db)
  }
}
