/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 16:15:17
 * @LastEditTime : 2022-10-08 22:35:53
 * @Description  : User Info Payload
 */

class UserInfo {
  final Map<String, Object?> _data;

  UserInfo({
    required int userID,
    required String userName,
    String? userAvatar
  }): _data = {
    "userid": userID,
    "username": userName,
    "avatar": userAvatar
  };
  UserInfo.fromJSONObject(Map<String, Object?> data): _data = data;

  int get userID => _data['userid'] as int;
  String get userName => _data['username'] as String;
  String? get userAvatar => _data['avatar'] as String?;
  Map<String, Object?> get jsonObject => _data;
}