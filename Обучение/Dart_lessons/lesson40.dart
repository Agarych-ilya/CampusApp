import 'dart:math';

void main() {
  final user = User(height: 1.90, weight: 87);
  print(user.bmi);
}

class User {
  User({required this.height, required this.weight}) {
    bmi = (weight / pow(height, 2));
  }

  final double height;
  final double weight;
  late final double bmi;
}
