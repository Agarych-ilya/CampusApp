void main() {
  var sanya = Human(name: 'Sasha', age: 23, height: 190);
  var vova = Human(name: 'Vova', age: 20, height: 170);

  print(sanya.isHight(vova));

  print(sanya);
  sanya.grewUp(2);

  print(sanya);
  print(vova);
}

class Human {
  Human({required this.name, required this.age, required this.height});

  final String name;
  int age;
  double height;

  void grewUp(int years) {
    age += years;
  }

  bool isHight(Human otherHuman) {
    return this.height > otherHuman.height;
  }

  @override
  String toString() {
    return 'Человек - Name: $name Age: $age Rost: $height';
  }
}
