void main() {
  var sanya = Human(name: 'Саша', age: 23, height: 190);
  print(sanya.name);
  print(Human.count);
  var vova = Human(name: 'Вова', age: 20, height: 180);
  print(vova.name);
  print(Human.count);
}

class Human {
  Human({required this.name, required this.age, required this.height}) {
    count += 1;
  }

  final String name;
  int age;
  double height;

  static int count = 0;
}
