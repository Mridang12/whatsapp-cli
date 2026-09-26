import Foundation
import SQLite
import Testing
@testable import WAMsgCore

@Test
func listChatsOrdersByRecentActiveSessions() throws {
  let store = try makeFixtureStore()
  let chats = try store.listChats(limit: 10)

  #expect(chats.map(\.id) == [7, 2, 1])
  #expect(chats[1].name == "Team Chat")
  #expect(chats[1].isGroup)
  #expect(chats[2].unreadCount == 2)
}

@Test
func listChatsCanIncludeSystemSessions() throws {
  let store = try makeFixtureStore()
  let chats = try store.listChats(limit: 10, includeSystemChats: true)

  #expect(chats.map(\.id) == [7, 6, 5, 4, 2, 1])
}

@Test
func exactChatsResolveNamesAndPhoneNumbersWithoutSystemSessions() throws {
  let store = try makeFixtureStore()

  #expect(try store.exactChats(matching: "Ada Lovelace").map(\.id) == [1])
  #expect(try store.exactChats(matching: "+15550001111@s.whatsapp.net").map(\.id) == [1])
  #expect(try store.exactChats(matching: "+1 (555) 000-1111").map(\.id) == [1])
  #expect(try store.exactChats(matching: "Mom").isEmpty)
}

@Test
func messagesDecodeDirectionSendersAndAttachments() throws {
  let store = try makeFixtureStore()
  let messages = try store.messages(chatID: 1, limit: 10)

  #expect(messages.map(\.rowID) == [2, 1])
  #expect(messages[0].isFromMe)
  #expect(messages[0].sender == "me")
  #expect(messages[1].sender == "+15550001111@s.whatsapp.net")
  #expect(messages[1].senderName == "Ada Lovelace")
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

  #expect(messages.map(\.rowID) == [2, 3, 10, 11, 12, 13, 14])
}

@Test
func messagesFollowWhatsAppSortOrderNotRowIDOrDate() throws {
  let store = try makeFixtureStore()

  let newest = try store.messages(chatID: 7, limit: 10)
  #expect(newest.map(\.text) == ["fifth", "fourth", "third", "second", "first"])

  let oldest = try store.messages(chatID: 7, limit: 10, filter: nil, order: .oldestFirst)
  #expect(oldest.map(\.text) == ["first", "second", "third", "fourth", "fifth"])
}

@Test
func messagesPageWithBeforeAndAfterCursors() throws {
  let store = try makeFixtureStore()

  let latestTwo = try store.messages(chatID: 7, limit: 2)
  #expect(latestTwo.map(\.text) == ["fifth", "fourth"])

  let olderPage = try store.messages(
    chatID: 7, limit: 2, filter: nil, beforeRowID: latestTwo.last?.rowID
  )
  #expect(olderPage.map(\.text) == ["third", "second"])

  let lastPage = try store.messages(
    chatID: 7, limit: 2, filter: nil, beforeRowID: olderPage.last?.rowID
  )
  #expect(lastPage.map(\.text) == ["first"])

  let forward = try store.messages(
    chatID: 7, limit: 2, filter: nil, order: .oldestFirst, afterRowID: 14
  )
  #expect(forward.map(\.text) == ["third", "fourth"])

  #expect(throws: WAMsgError.messageNotFound(rowID: 1, chatID: 7)) {
    _ = try store.messages(chatID: 7, limit: 2, filter: nil, beforeRowID: 1)
  }
}

@Test
func groupMessagesUseMemberSenderAndIgnoreEncodedPushNames() throws {
  let store = try makeFixtureStore()
  let messages = try store.messages(chatID: 2, limit: 10)

  #expect(messages.count == 1)
  #expect(messages[0].sender == "+15550002222@s.whatsapp.net")
  #expect(messages[0].senderName == "Ben Bitdiddle")
  #expect(messages[0].attachmentsCount == 0)
  #expect(try store.attachments(for: 3).isEmpty)

  let filtered = try store.messages(
    chatID: 2,
    limit: 10,
    filter: WhatsAppMessageFilter(participants: ["+15550002222@s.whatsapp.net"])
  )
  #expect(filtered.map(\.rowID) == [3])

  let lidMessages = try store.messages(chatID: 7, limit: 1, filter: nil, order: .oldestFirst)
  #expect(lidMessages[0].senderName == "Lid Friend")
}

@Test
func chatsUseLastMessageRowTextInsteadOfEncodedSnapshot() throws {
  let store = try makeFixtureStore()
  let chat = try store.chatInfo(chatID: 2)

  #expect(chat?.lastMessageText == "group hello")
}

@Test
func lidIdentifiersAreNotPhoneNumbers() {
  #expect(WhatsAppStore.phoneNumber(fromIdentifier: "27771426349309@lid") == nil)
  #expect(WhatsAppStore.phoneNumber(fromIdentifier: "12345@g.us") == nil)
  #expect(WhatsAppStore.phoneNumber(fromIdentifier: "+15550001111@s.whatsapp.net") == "15550001111")
  #expect(WhatsAppStore.phoneNumber(fromIdentifier: "+1 (555) 000-1111") == "15550001111")
  #expect(WhatsAppStore.phoneNumber(fromIdentifier: "Jane Doe") == nil)
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
