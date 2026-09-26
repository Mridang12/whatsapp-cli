import Foundation
import SQLite
@testable import WAMsgCore

func makeFixtureStore() throws -> WhatsAppStore {
  let db = try Connection(.inMemory)
  let baseDate = WhatsAppStore.whatsappEpoch(Date(timeIntervalSince1970: 1_700_000_000))
  try db.execute(
    """
    CREATE TABLE ZWACHATSESSION (
      Z_PK INTEGER PRIMARY KEY,
      ZCONTACTJID TEXT,
      ZPARTNERNAME TEXT,
      ZLASTMESSAGETEXT TEXT,
      ZLASTMESSAGEDATE REAL,
      ZUNREADCOUNT INTEGER,
      ZARCHIVED INTEGER,
      ZREMOVED INTEGER,
      ZSESSIONTYPE INTEGER,
      ZLASTMESSAGE INTEGER
    );
    CREATE TABLE ZWAMESSAGE (
      Z_PK INTEGER PRIMARY KEY,
      ZCHATSESSION INTEGER,
      ZGROUPMEMBER INTEGER,
      ZMEDIAITEM INTEGER,
      ZISFROMME INTEGER,
      ZTEXT TEXT,
      ZMESSAGEDATE REAL,
      ZSTANZAID TEXT,
      ZFROMJID TEXT,
      ZTOJID TEXT,
      ZMESSAGETYPE INTEGER,
      ZMESSAGESTATUS INTEGER,
      ZMESSAGEERRORSTATUS INTEGER,
      ZPUSHNAME TEXT,
      ZSORT INTEGER
    );
    CREATE TABLE ZWAMEDIAITEM (
      Z_PK INTEGER PRIMARY KEY,
      ZMESSAGE INTEGER,
      ZMEDIALOCALPATH TEXT,
      ZTHUMBNAILLOCALPATH TEXT,
      ZTITLE TEXT,
      ZVCARDNAME TEXT,
      ZFILESIZE INTEGER,
      ZMEDIAURL TEXT,
      ZMETADATA BLOB
    );
    CREATE TABLE ZWAGROUPMEMBER (
      Z_PK INTEGER PRIMARY KEY,
      ZCHATSESSION INTEGER,
      ZMEMBERJID TEXT,
      ZISACTIVE INTEGER,
      ZCONTACTNAME TEXT,
      ZFIRSTNAME TEXT
    );
    CREATE TABLE ZWAPROFILEPUSHNAME (
      ZJID TEXT,
      ZPUSHNAME TEXT
    );

    INSERT INTO ZWACHATSESSION VALUES
      (1, '+15550001111@s.whatsapp.net', 'Ada Lovelace', 'reply', \(baseDate + 10), 2, 0, 0, 0, NULL),
      (2, '12345@g.us', 'Team Chat', 'CgAQencodedblob=', \(baseDate + 20), 0, 0, 0, 1, 3),
      (3, '+15550003333@s.whatsapp.net', 'Removed', 'old', \(baseDate - 100), 0, 0, 1, 0, NULL),
      (4, '+15550001111@status', 'Mom', 'status update', \(baseDate + 30), 0, 0, 0, 0, NULL),
      (5, 'status@broadcast', 'Status', 'broadcast status', \(baseDate + 40), 0, 0, 0, 0, NULL),
      (6, '98765@lid.status', 'Lid Status', 'lid status update', \(baseDate + 50), 0, 0, 0, 3, NULL),
      (7, '27771426349309@lid', 'Lid Friend', 'later', \(baseDate + 300), 0, 0, 0, 0, NULL);

    INSERT INTO ZWAMESSAGE VALUES
      (1, 1, NULL, 1, 0, 'hello', \(baseDate), 'stanza-1', '+15550001111@s.whatsapp.net', '', 0, 0, 0, 'Ada', 1),
      (2, 1, NULL, NULL, 1, 'reply', \(baseDate + 10), 'stanza-2', '', '+15550001111@s.whatsapp.net', 0, 6, 0, '', 2),
      (3, 2, 1, 2, 0, 'group hello', \(baseDate + 20), 'stanza-3', '12345@g.us', '', 0, 0, 0, 'CgAQencodedblob=', 1),
      -- Row ids and dates deliberately disagree with WhatsApp's ZSORT conversation order.
      (10, 7, NULL, NULL, 0, 'first', \(baseDate + 100), 'stanza-10', '27771426349309@lid', '', 0, 0, 0, 'CgAQblob=', 1),
      (14, 7, NULL, NULL, 1, 'second', \(baseDate + 200), 'stanza-14', '', '27771426349309@lid', 0, 6, 0, '', 2),
      (11, 7, NULL, NULL, 0, 'third', \(baseDate + 190), 'stanza-11', '27771426349309@lid', '', 0, 0, 0, '', 3),
      (13, 7, NULL, NULL, 0, 'fourth', \(baseDate + 250), 'stanza-13', '27771426349309@lid', '', 0, 0, 0, '', 4),
      (12, 7, NULL, NULL, 1, 'fifth', \(baseDate + 300), 'stanza-12', '', '27771426349309@lid', 0, 6, 0, '', 5);

    INSERT INTO ZWAMEDIAITEM VALUES
      (1, 1, '/tmp/photo.jpg', '/tmp/photo-thumb.jpg', 'photo.jpg', '', 42, 'https://example.invalid/photo.jpg', NULL),
      (2, 3, NULL, NULL, NULL, NULL, 0, NULL, X'0102');

    INSERT INTO ZWAGROUPMEMBER VALUES
      (1, 2, '+15550002222@s.whatsapp.net', 1, 'Ben Bitdiddle', 'Ben'),
      (2, 2, '+15550002222@s.whatsapp.net', 1, 'Ben Bitdiddle', 'Ben'),
      (3, 2, '+15550004444@s.whatsapp.net', 0, 'Inactive', 'Inactive');

    INSERT INTO ZWAPROFILEPUSHNAME VALUES
      ('+15550001111@s.whatsapp.net', 'Ada'),
      ('+15550002222@s.whatsapp.net', 'Ben');
    """
  )
  return try WhatsAppStore(connection: db)
}
