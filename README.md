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
