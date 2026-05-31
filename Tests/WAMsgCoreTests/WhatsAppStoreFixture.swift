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
      ZSESSIONTYPE INTEGER
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
      ZPUSHNAME TEXT
    );
    CREATE TABLE ZWAMEDIAITEM (
      Z_PK INTEGER PRIMARY KEY,
      ZMESSAGE INTEGER,
      ZMEDIALOCALPATH TEXT,
      ZTHUMBNAILLOCALPATH TEXT,
      ZTITLE TEXT,
      ZVCARDNAME TEXT,
      ZFILESIZE INTEGER,
      ZMEDIAURL TEXT
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
      (1, '+15550001111@s.whatsapp.net', 'Ada Lovelace', 'reply', \(baseDate + 10), 2, 0, 0, 0),
      (2, '12345@g.us', 'Team Chat', 'group hello', \(baseDate + 20), 0, 0, 0, 1),
      (3, '+15550003333@s.whatsapp.net', 'Removed', 'old', \(baseDate - 100), 0, 0, 1, 0);

    INSERT INTO ZWAMESSAGE VALUES
      (1, 1, NULL, 1, 0, 'hello', \(baseDate), 'stanza-1', '+15550001111@s.whatsapp.net', '', 0, 0, 0, 'Ada'),
      (2, 1, NULL, NULL, 1, 'reply', \(baseDate + 10), 'stanza-2', '', '+15550001111@s.whatsapp.net', 0, 6, 0, ''),
      (3, 2, 1, NULL, 0, 'group hello', \(baseDate + 20), 'stanza-3', '', '', 0, 0, 0, '');

    INSERT INTO ZWAMEDIAITEM VALUES
      (1, 1, '/tmp/photo.jpg', '/tmp/photo-thumb.jpg', 'photo.jpg', '', 42, 'https://example.invalid/photo.jpg');

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

