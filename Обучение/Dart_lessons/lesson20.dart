void main() {
  var sanya = Human(name: 'Sasha', age: 23, height: 190);
  print(sanya);
}

class Human {
  Human({required this.name, required int age, required this.height})
    : _age = age;
  int get age => _age;
  String get nameAndAge => '$name: $age';

  final String name;
  int _age;
  double height;

  void grewUp(int years) {
    _age += years;
  }

  bool isHight(Human otherHuman) {
    return this.height > otherHuman.height;
  }

  @override
  String toString() {
    return 'Человек - Name: $name Age: $_age Rost: $height';
  }
}
