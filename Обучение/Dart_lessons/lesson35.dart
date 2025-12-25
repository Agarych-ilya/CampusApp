void main() {
  final sasha = User(
    name: 'Саша',
    email: 'didhduhudh@gmail.com',
    phone: '+73545343',
  );
  print(sasha.displayName);
}

class User {
  const User({this.name, this.email, this.phone});

  final String? name;
  final String? email;
  final String? phone;

  String get displayName => name ?? email ?? phone ?? 'Имя не указано';
}
