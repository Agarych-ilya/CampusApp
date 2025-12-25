void main() {
  var sanya = Human(name: 'Sasha', age: 23, height: 190);
  Human alice = Artist(name: 'Alice', age: 20, height: 165, style: "3D");

  print(sanya);
  print(alice);
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

class Artist extends Human {
  Artist({
    required super.name,
    required super.age,
    required super.height,
    required this.style,
  });

  String style;

  @override
  String toString() {
    return super.toString() + ' ' + 'Style: $style';
  }
}
