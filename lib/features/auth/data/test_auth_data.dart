
class TestAuthData {
  static const String email = 'test@campus.ru';
  static const String password = '123456';

  static bool isValidLogin({
    required String inputEmail,
    required String inputPassword,
  }) {
    return inputEmail.trim().toLowerCase() == email &&
        inputPassword.trim() == password;
  }
}