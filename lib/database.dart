/*
 * @Author       : Linloir
 * @Date         : 2022-10-06 16:15:01
 * @LastEditTime : 2022-10-22 21:08:27
 * @Description  : 
 */

import 'dart:io';

import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tcp_server/tcpcontroller/payload/identity.dart';
import 'package:tcp_server/tcpcontroller/payload/message.dart';
import 'package:tcp_server/tcpcontroller/payload/userinfo.dart';

class DataBaseHelper {
  static final DataBaseHelper _helper = DataBaseHelper._internal();
  late final Database _database;

  factory DataBaseHelper() {
    return _helper;
  }

  DataBaseHelper._internal();

  Future<void> initialize() async {
    _database = await databaseFactoryFfi.openDatabase(
      '${Directory.current.path}/.data/.tmp/database.db',
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          print('[L] Creating Database.');
          await db.execute(
            '''
              CREATE TABLE users (
                userid    integer primary key autoincrement,
                username  text unique not null,
                passwd    text not null,
                avatar    text
              );
              create table msgs (
                userid      integer,
                targetid    integer,
                contenttype text not null,
                content     text not null,
                timestamp   integer,
                md5encoded  text primary key not null
              );
              create table contacts (
                userid    integer,
                targetid  integer,
                primary key (userid, targetid)
              );
              create table tokens (
                tokenid     integer primary key autoincrement,
                createtime  integer not null,
                lastused    integer not null
              );
              create table bindings (
                tokenid   integer primary key,
                userid    integer
              );
              create table histories (
                tokenid       integer,
                userid        integer,
                lastfetch     integer not null,
                primary key (tokenid, userid)
              );
              create table files (
                filemd5   text primary key not null,
                dir       text not null
              );
              create table msgfiles (
                msgmd5    text not null,
                filemd5   text not null,
                primary key (msgmd5, filemd5)
              );
            '''
          );
          print('[L] Database created');
        },
      )
    );
  }

  Future<bool> isTokenValid({
    required int? tokenid,
  }) async {
    if(tokenid == null) {
      return false;
    }

    var tokenQueryResult = await _database.query(
      'tokens',
      where: 'tokenid = ?',
      whereArgs: [
        tokenid
      ]
    );

    return tokenQueryResult.isNotEmpty;
  }

  //Creates new token
  Future<int> createToken() async {
    //Insert new row
    var row = await _database.rawInsert(
      '''
        insert into tokens(createtime, lastused)
          values (?, ?)
      ''',
      [
        DateTime.now().millisecondsSinceEpoch,
        DateTime.now().millisecondsSinceEpoch
      ]
    );
    //Fetch new row
    var newToken = (await _database.query(
      'tokens',
      where: 'rowid = $row',
    ))[0]['tokenid'] as int;
    //Return token
    return newToken;
  }

  Future<UserInfo> checkLoginState({
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }

    var bindingQueryResult = await _database.query(
      'bindings natural join users',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    );
    if(bindingQueryResult.isNotEmpty) {
      return UserInfo(
        userID: bindingQueryResult[0]['userid'] as int, 
        userName: bindingQueryResult[0]['username'] as String,
        userAvatar: bindingQueryResult[0]['avatar'] as String?
      );
    }
    else {
      throw Exception('User not logged in');
    }
  }

  Future<UserInfo> logIn({
    required UserIdentity identity,
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }

    var userIdentities = await _database.query(
      'users',
      where: 'username = ?',
      whereArgs: [
        identity.userName
      ]
    );
    if(userIdentities.isNotEmpty) {
      var user = userIdentities[0];
      if(user['passwd'] == identity.userPasswd) {
        //Query for existed token binding
        var existBindings = await _database.query(
          'bindings',
          where: 'tokenid = ?',
          whereArgs: [
            tokenID
          ]
        );
        if(existBindings.isEmpty) {
          //Add new binding
          await _database.insert(
            'bindings',
            {
              'tokenid': tokenID,
              'userid': user['userid']
            }
          );
        }
        else {
          //Update token binding
          await _database.update(
            'bindings',
            {
              'tokenid': tokenID,
              'userid': user['userid']
            },
            where: 'tokenid = ?',
            whereArgs: [
              tokenID
            ]
          );
        }
        return UserInfo(
          userID: user['userid'] as int, 
          userName: user['username'] as String,
          userAvatar: user['avatar'] as String?
        );
      }
      else {
        throw Exception('Invalid password');
      }
    }
    else {
      throw Exception('User not found');
    }
  }

  Future<void> logOut({
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Delete binding
    await _database.delete(
      'bindings',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    );
  }

  Future<UserInfo> registerUser({
    required UserIdentity identity,
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Insert into users
    try {
      await _database.transaction((txn) async {
        var result = await txn.query(
          'users',
          where: 'username = ?',
          whereArgs: [
            identity.userName
          ]
        );
        if(result.isNotEmpty) {
          throw Exception('Username already exists');
        }
        await txn.insert(
          'users',
          {
            'username': identity.userName,
            'passwd': identity.userPasswd,
            'avatar': null
          },
          conflictAlgorithm: ConflictAlgorithm.rollback
        );
      });
    } catch (e) {
      rethrow;
    }

    //Get new userid
    var newUserID = (await _database.query(
      'users',
      where: 'username = ?',
      whereArgs: [
        identity.userName
      ]
    ))[0]['userid'] as int;

    //Insert into bindings
    await _database.insert(
      'bindings',
      {
        'tokenid': tokenID,
        'userid': newUserID
      }
    );

    return UserInfo(
      userID: newUserID,
      userName: identity.userName,
      userAvatar: null
    );
  }

  Future<void> modifyUserPassword({
    required UserIdentity newIdentity,
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Find current binded user
    var currentUserQueryResult = await _database.query(
      'bindings natural join users',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    );
    if(currentUserQueryResult.isEmpty) {
      throw Exception('User not logged in');
    }
    var currentUser = currentUserQueryResult[0];
    
    //Verify user identity
    if(currentUser['passwd'] as String != newIdentity.userPasswd) {
      throw Exception('Wrong password');
    }
    else {
      try {
        //Modify database
        await _database.update(
          'users',
          {
            'passwd': newIdentity.userPasswdNew
          },
          where: 'userid = ${currentUser['userid'] as int}',
          conflictAlgorithm: ConflictAlgorithm.rollback
        );
      } catch (conflict) {
        throw Exception(['Database failure', conflict.toString()]);
      }
    }
  }

  //Returns a list of unfetched messages in JSON format
  Future<List<Message>> fetchMessagesFor({
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }

    //Find userID and last fetched time
    var userIdQueryResult = await _database.query(
      'bindings natural left outer join histories',
      columns: ['userid', 'lastfetch'],
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    );
    if(userIdQueryResult.isEmpty) {
      throw Exception('User not logged in');
    }
    var userID = userIdQueryResult[0]['userid'] as int;
    var lastFetch = userIdQueryResult[0]['lastfetch'] as int?;
    if(lastFetch == null) {
      //First fetch, add to fetch history
      await _database.insert(
        'histories',
        {
          'tokenid': tokenID,
          'userid': userID,
          'lastfetch': 0
        }
      );
      lastFetch = 0;
    }

    //Fetch unfetched messages
    var unfetchMsgQueryResult = await _database.query(
      'msgs left outer join msgfiles on msgs.md5encoded = msgfiles.msgmd5',
      columns: [
        'msgs.userid as userid',
        'msgs.targetid as targetid',
        'msgs.contenttype as contenttype',
        'msgs.content as content',
        'msgs.timestamp as timestamp',
        'msgs.md5encoded as md5encoded',
        'msgfiles.filemd5 as filemd5'
      ],
      where: '(userid = ? or targetid = ?) and timestamp > ?',
      whereArgs: [
        userID,
        userID,
        lastFetch
      ],
      orderBy: 'timestamp desc'
    );
    var unfetchMessages = unfetchMsgQueryResult.map((message) {
      return Message(
        userid: message['userid'] as int,
        targetid: message['targetid'] as int,
        contenttype: MessageType.fromStringLiteral(
          message['contenttype'] as String
        ),
        content: message['content'] as String,
        timestamp: message['timestamp'] as int,
        md5encoded: message['md5encoded'] as String,
        filemd5: message['filemd5'] as String?
      );
    }).toList();

    //Set new fetch history
    // if(unfetchMsgQueryResult.isNotEmpty) {
    //   await _database.update(
    //     'histories',
    //     {
    //       'lastfetch': unfetchMsgQueryResult[0]['timestamp']
    //     },
    //     where: 'tokenid = ? and userid = ?',
    //     whereArgs: [
    //       tokenID,
    //       userID
    //     ]
    //   );
    // }
    
    //return result
    return unfetchMessages;
  }

  Future<void> setFetchHistoryFor({
    required int? tokenID,
    required int newTimeStamp
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Get current userid
    var bindingQueryResult = await _database.query(
      'bindings natural left outer join histories',
      where: 'bindings.tokenid = ?',
      whereArgs: [
        tokenID
      ]
    );
    if(bindingQueryResult.isEmpty) {
      //Be silence on err
      return;
    }
    var userID = bindingQueryResult[0]['userid'] as int;

    //Check for fetch history
    var lastFetch = bindingQueryResult[0]['lastfetch'] as int?;
    if(lastFetch == null) {
      //First fetch, add to fetch history
      await _database.insert(
        'histories',
        {
          'tokenid': tokenID,
          'userid': userID,
          'lastfetch': newTimeStamp
        }
      );
    }
    else {
      //Update fetch history
      await _database.update(
        'histories',
        {
          'lastfetch': newTimeStamp
        },
        where: 'tokenid = ? and userid = ?',
        whereArgs: [
          tokenID,
          userID
        ]
      );
    }
  }

  Future<void> storeMessage({
    required Message msg,
    String? fileMd5
  }) async {
    try {
      await _database.insert(
        'msgs',
        {
          'userid': msg.senderID,
          'targetid': msg.receiverID,
          'contenttype': msg.contentType.literal,
          'content': msg.content,
          'timestamp': msg.timestamp,
          'md5encoded': msg.md5encoded,
        }
      );
    } catch (err) {
      print('[E] Database failure on message storage:');
      print('[>] $err');
    }
    if(msg.contentType == MessageType.file) {
      if(fileMd5 == null) {
        await _database.delete(
          'msgs',
          where: 'md5encoded = ?',
          whereArgs: [
            msg.md5encoded
          ]
        );
        throw Exception('Missing file for message');
      }
      await _database.insert(
        'msgfiles',
        {
          'msgmd5': msg.md5encoded,
          'filemd5': fileMd5
        },
        conflictAlgorithm: ConflictAlgorithm.replace
      );
    }
  }

  Future<void> storeFile({
    required File? tempFile,
    required String? fileMd5
  }) async {
    if(tempFile == null || fileMd5 == null) {
      throw Exception('Missing file parts');
    }
    var filePath = '${Directory.current.path}/.data/files/$fileMd5';
    await tempFile.copy(filePath);
    try {
      var sameFile = await _database.query(
        'files',
        where: 'filemd5 = ?',
        whereArgs: [
          fileMd5
        ]
      );
      if(sameFile.isNotEmpty) {
        return;
      }
      await _database.insert(
        'files',
        {
          'filemd5': fileMd5,
          'dir': filePath
        },
        conflictAlgorithm: ConflictAlgorithm.rollback
      );
    } catch (conflict) {
      throw Exception(['Database failure', conflict.toString()]);
    }
  }

  Future<bool> findFile({
    required String fileMd5
  }) async {
    var targetFile = await _database.query(
      'files',
      where: 'filemd5 = ?',
      whereArgs: [
        fileMd5
      ]
    );
    return targetFile.isNotEmpty;
  }

  Future<String> fetchFilePath({
    required String msgMd5
  }) async {
    var queryResult = await _database.query(
      'msgfiles natural join files',
      where: 'msgfiles.msgmd5 = ?',
      whereArgs: [
        msgMd5
      ]
    );
    if(queryResult.isEmpty) {
      throw Exception('File not found');
    }
    return queryResult[0]['dir'] as String;
  }

  Future<UserInfo> fetchUserInfoViaID({
    required int userid
  }) async {
    
    //Find current binded userID
    var userQueryResult = (await _database.query(
      'users',
      where: 'userid = ?',
      whereArgs: [
        userid
      ]
    ));

    if(userQueryResult.isEmpty) {
      throw Exception('User not found');
    }
    
    return UserInfo(
      userID: userQueryResult[0]['userid'] as int,
      userName: userQueryResult[0]['username'] as String,
      userAvatar: userQueryResult[0]['avatar'] as String?
    );
  }

  Future<UserInfo> modifyUserInfo({
    required UserInfo userInfo,
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Find current binded userID
    var currentUserIDQueryResult = (await _database.query(
      'bindings',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    ));
    if(currentUserIDQueryResult.isEmpty) {
      throw Exception('User not logged in');
    }
    var currentUserID = currentUserIDQueryResult[0]['userid'] as int;

    //Update database
    try {
      await _database.update(
        'users',
        {
          'username': userInfo.userName,
          'avatar': userInfo.userAvatar
        },
        where: 'userid = ?',
        whereArgs: [
          currentUserID
        ],
        conflictAlgorithm: ConflictAlgorithm.rollback
      );
    } catch (conflict) {
      throw Exception(['Database failure', conflict.toString()]);
    }

    //Return result
    return UserInfo(
      userID: currentUserID,
      userName: userInfo.userName,
      userAvatar: userInfo.userAvatar
    );
  }

  Future<UserInfo> fetchUserInfoViaUsername({
    required String username
  }) async {
    var targetUserQueryResult = await _database.query(
      'users',
      columns: [
        'userid',
        'username',
        'avatar'
      ],
      where: 'username = ?',
      whereArgs: [
        username
      ]
    );
    if(targetUserQueryResult.isNotEmpty) {
      return UserInfo(
        userID: targetUserQueryResult[0]['userid'] as int,
        userName: targetUserQueryResult[0]['username'] as String,
        userAvatar: targetUserQueryResult[0]['avatar'] as String?
      );
    }
    else {
      throw Exception('User not found');
    }
  }

  Future<List<UserInfo>> fetchContact({
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Find current binded userID
    var currentUserIDQueryResult = (await _database.query(
      'bindings',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    ));
    
    if(currentUserIDQueryResult.isEmpty) {
      throw Exception('User not logged in');
    }

    var currentUserID = currentUserIDQueryResult[0]['userid'] as int;

    //Fetch all contacts
    var contactsQueryResult = await _database.query(
      'contacts as I join contacts as P on I.targetid = P.userid join users on I.targetid = users.userid',
      columns: ['I.targetid as userid', 'users.username as username', 'users.avatar as avatar'],
      where: 'I.userid = P.targetid and I.userid = ?',
      whereArgs: [
        currentUserID
      ]
    );

    //Convert to encodable objects
    var contactsEncodable = contactsQueryResult.map((contact) {
      return UserInfo(
        userID: contact['userid'] as int,
        userName: contact['username'] as String,
        userAvatar: contact['avatar'] as String?
      );
    }).toList();

    return contactsEncodable;
  }

  Future<List<UserInfo>> fetchPendingContacts({
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    var currentUserIDQueryResult = (await _database.query(
      'bindings',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    ));
    
    if(currentUserIDQueryResult.isEmpty) {
      throw Exception('User not logged in');
    }

    var currentUserID = currentUserIDQueryResult[0]['userid'] as int;

    //Fetch pending contacts
    var contactsQueryResult = await _database.query(
      'contacts join users on contacts.targetid = users.userid',
      columns: ['contacts.targetid as userid', 'users.username as username', 'users.avatar as avatar'],
      where: '''contacts.userid = ? and not exists (
          select * from contacts as S 
          where contacts.targetid = S.userid and contacts.userid = S.targetid
        )''',
      whereArgs: [
        currentUserID
      ]
    );

    //Convert to encodable objects
    var contactsEncodable = contactsQueryResult.map((contact) {
      return UserInfo(
        userID: contact['userid'] as int,
        userName: contact['username'] as String,
        userAvatar: contact['avatar'] as String?
      );
    }).toList();

    return contactsEncodable;
  }

  Future<List<UserInfo>> fetchRequestingContacts({
    required int? tokenID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Find current binded userID
    var currentUserIDQueryResult = (await _database.query(
      'bindings',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    ));
    
    if(currentUserIDQueryResult.isEmpty) {
      throw Exception('User not logged in');
    }

    var currentUserID = currentUserIDQueryResult[0]['userid'] as int;
    
        //Fetch pending contacts
    var contactsQueryResult = await _database.query(
      'contacts join users on contacts.userid = users.userid',
      columns: ['contacts.userid as userid', 'users.username as username', 'users.avatar as avatar'],
      where: '''contacts.targetid = ? and not exists (
          select * from contacts as S 
          where contacts.targetid = S.userid and contacts.userid = S.targetid
        )''',
      whereArgs: [
        currentUserID
      ]
    );

    //Convert to encodable objects
    var contactsEncodable = contactsQueryResult.map((contact) {
      return UserInfo(
        userID: contact['userid'] as int,
        userName: contact['username'] as String,
        userAvatar: contact['avatar'] as String?
      );
    }).toList();

    return contactsEncodable;
  }

  Future<void> addContact({
    required int? tokenID,
    required int userID
  }) async {
    if(tokenID == null) {
      throw Exception('Invalid device token');
    }
    
    //Find current binded userID
    var currentUserID = (await _database.query(
      'bindings',
      where: 'tokenid = ?',
      whereArgs: [
        tokenID
      ]
    ))[0]['userid'] as int;

    //Add contacts
    await _database.insert(
      'contacts',
      {
        'userid': currentUserID,
        'targetid': userID
      },
      conflictAlgorithm: ConflictAlgorithm.ignore
    );
  }

  Future<List<int>> fetchTokenIDsViaUserID({
    required int userID
  }) async {
    var tokenIDQueryResult = await _database.query(
      'bindings',
      where: 'userid = ?',
      whereArgs: [
        userID
      ]
    );

    return tokenIDQueryResult.map((token) {
      return token['tokenid'] as int;
    }).toList();
  }
}
