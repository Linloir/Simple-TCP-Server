# Simple TCP Server

This is ~~a project of my Computer Internet course~~ a project inspired by my school homework.

Several days before I'm asked to write a project on TCP server-client communication, and I wondered why not build a simple chat service beyond that which would be much more fun?

Therefore here it is, a simple tcp server with several functions which makes it acts like a small chat app.

## Functions

- User register / login / logout
- Remember login state for device (simple token approach though)
- Send messages via users
- Search users and add contacts (and accept them of course)
- Message sync via different devices
- Send message to offline server (a SMTP-like approach)
- File handling (transfer to and fetch from server)

## Notice

- To support multilanguage, use `base64Encode(utf8.encode(yourMessageHere))` before wrapping client messages in json object and sending that to the server (the serve will crash!)
- Always open a new TCP connection to fetch or send file

## Compile and Deploy

To clone and run this project in command prompt, do the following under Windows environment with dart SDK configured.

```bash
git clone https://github.com/Linloir/Simple-TCP-Server.git
cd Simple-TCP-Server

# [+] In case you want to build an exe
# mkdir build
# dart compile exe ./bin/tcp_server.dart -o ./build/tcp_server.exe
# cd build
# tcp_server.exe

dart run
```

## Application Layer Protocol

Since I was not allowed to base my homework on an existing HTTP protocol, I create my private protocol for this project.

To communicate with the server, your data should conform the following formats:

### Overall Request / Response Structure

Every request sent by any client to this server should and should only consist four regions:

- Request length region (4 bytes)
- Payload length region (4 bytes)
- Request JSON (variable length)
- Payload byte stream (variable length)

Each section should interconnect with each other with no byte insets.

### Request JSON Region

The request JSON region is self-explanatory, which contains a encoded JSON string describing the request from the client.

#### Fields of Request JSON

To get use of the JSON object, all you need is the table below describing the supported fields in a JSON object and the possible combinations between them:

| Field | Content | Meaning |
|:-----:|:-------:|:-------:|
| `request` | <ul style="text-align:left"><li>`STATE`: Check for the current login state *(also used to fetch a token for first used device)*</li><li>`REGISTER`: Register new user</li><li>`LOGIN`: Login via username and password</li><li>`LOGOUT`: Logout current device</li><li>`SENDMSG`: Send message to user</li><li>`FETCHMSG`: Fetch messages sent to or from the logged user that haven't been fetched by current device</li><li>`SEARCHUSR`: Search user info via username</li><li>`ADDCONTACT`: Add contact via userid</li><li>`FETCHCONTACT`: Get the contact *(Including both dual-sided and single-sided contacts)*</li><li>`FETCHFILE`: Fetch the attached file of a message</li></ul> | The type of the request |
| `body` | *JSON object* | The information needed for the request |
| `tokenid` | *number \| null* | The identifier of a device |

#### Body of Request JSON

The body field of the JSON object is the key part of a request; it contains the key information the server needs to perform the request command.

There are mainly four different types of a body:

The **UserInfo** body is used to describe the information of an arbitrary user:

- `userid`: The user ID
- `username`: The username
- `avatar`: The base64 encoded form of the user's avatar

The **UserIdentity** body is used as a credential of a specific user:

- `username`: The username
- `passwd`: The password of the user
- `newPasswd`: The modified password *(Should only exists if a user is trying to modify his/hers password)*

The **Message** body is used to describe a message:

- `userid`: The user ID of the sender
- `targetid`: The user ID of the reciever
- `contenttype`: The type of content attached to the message, should only contain values among `plaintext`, `image` and `file`
- `content`: The base64encoded utf8encoded string of the original message *(Should contain filename if the content type is 'file')*
- `md5encoded`: The calculated md5 value of the encoded content string
- `filemd5`: The attached file's md5 value *(Calculated at client side before sending the request; should only exist if the content type is 'file')*

The **MessageIdentifier** is the identifier for a client to fetch a file for a message, it contains only the necessary part to identify a message:

- `msgmd5`: The md5 of the message

The **UserName** or **UserID** is self-explanatory, which contains only the username of a user in order to search the full info of the user:

- `username`: The provided username **Or** `userid`: The provided user ID

The usage of different body parts for different request types is described below:

| Request Type | Body Part Contents |
|:------------:|:------------------:|
|`STATE`| *NONE* |
|`REGISTER`| **UserIdentity** |
|`LOGIN`| **UserIdentity** |
|`LOGOUT`| *NONE* |
|`SENDMSG`| **Message** |
|`FETCHMSG`| *NONE* |
|`FETCHFILE`| **MessageIdentifier** |
|`SEARCHUSR`| **UserName** |
|`ADDCONTACT`| **UserID** |
|`FETCHCONTACT`| *NONE* |

### Response JSON Region

#### Fields of Response JSON

The fields of a response JSON is similar to that of a request JSON, excludes for the `tokenid` field.

The response JSON also offers extra fields to describe the state of a performed command:

| Field | Content | Meaning |
|:-----:|:-------:|:-------:|
|`status`|<ul style="text-align:left"><li>`OK`: The request completes with no err</li><li>`ERR`: The request completes with at least one err</li></ul>| The completion status of the request |
|`info`| *String \| null* | Description of error *(Only exists if the status is 'ERR')* |

#### Body of Response JSON

The body of a response JSON object contains all possible types of a request JSON object, with the addition of two special types below.

The **TokenInfo** body is self-explanatory, which carries the info of a token. This kind of response body only appears in an extra response preceding the original responsse of the first request from a new client device, which offers the client device a token number:

- `tokenid`: The allocated token ID

The **MessageList** body is also self-explanatory, which is a list of **Message** objects, this kind of response body exists in a `FETCHMSG` response:

- `messages`: A list of **Message** objects
