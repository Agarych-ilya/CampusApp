import 'lesson20.dart';

void main() {
  var sanya = Human(name: 'Sasha', age: 23, height: 190);
  print(sanya.age);
  sanya.grewUp(3);

  print(sanya.age);
  print(sanya.nameAndAge);
}
