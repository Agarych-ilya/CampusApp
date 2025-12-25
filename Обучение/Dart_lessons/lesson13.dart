void main() {
  print_Otvet_calculate();
}

num calculate(num a, num b, num Function(num a, num b) action) {
  return action(a, b);
}

void print_Otvet_calculate() {
  final sum = (num a, num b) => a + b;
  final dif = (num a, num b) => a - b;
  final div = (num a, num b) => a / b;
  final mult = (num a, num b) => a * b;
  print(calculate(1, 2, sum));
  print(calculate(1, 2, dif));
  print(calculate(1, 2, div));
  print(calculate(1, 2, mult));
}
