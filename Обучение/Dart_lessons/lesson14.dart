void main() {
  print(greaterOrLess(2, 2));
}

String greaterOrLess(int a, int b) {
  if (a == b) return '==';
  return a > b ? '1' : '0';
}
