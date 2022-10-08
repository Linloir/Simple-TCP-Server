/*
 * @Author       : Linloir
 * @Date         : 2022-10-08 16:16:10
 * @LastEditTime : 2022-10-08 22:36:19
 * @Description  : 
 */

class UserIdentity {
  final Map<String, Object?> _data;

  UserIdentity({
    required String userName,
    required String userPasswdEncoded,
    String? userPasswdEncodedNew
  }): _data = {
    "username": userName,
    "passwd": userPasswdEncoded,
    "newPasswd": userPasswdEncodedNew
  };
  UserIdentity.fromJSONObject(Map<String, Object?> data): _data = data;

  String get userName => _data['username'] as String;
  String get userPasswd => _data['passwd'] as String;
  String? get userPasswdNew => _data['newPasswd'] as String?;
  Map<String, Object?> get jsonObject => _data;
}