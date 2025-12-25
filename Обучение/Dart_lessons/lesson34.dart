void main() {
  String? name = _getUserName();
  print(_getFirstChar(name));
}

String? _getUserName() {
  return "Fedya";
}

String? _getFirstChar(String? name) {
  return name?.substring(0, 1);
}
