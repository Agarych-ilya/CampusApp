void main() {
  const sanya = Human(name: 'Саша', age: 23, height: 190);

  final kostya = sanya.copyWith(name: "Костян");

  print(sanya.nameAndAge);
  print(kostya.nameAndAge);
}

class Human {
  const Human({required this.name, required int age, required this.height})
    : _age = age;
  int get age => _age;
  String get nameAndAge => '$name: $age';

  final String name;
  final int _age;
  final double height;

  Human copyWith({String? name, int? age, double? height}) {
    return Human(
      name: name ?? this.name,
      age: age ?? this.age,
      height: height ?? this.height,
    );
  }
}
