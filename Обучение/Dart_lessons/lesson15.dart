void main() {
  try {
    print(divide(1, 0));
  } on Error catch (e) {
    print('aaaaaaaaaa!\n' + e.toString());
  } on Exception catch (e) {
    print('error\n' + e.toString());
  }

  print('exit');
}

num divide(num a, num b) {
  if (b == 0) {
    throw Exception('Делить на ноль нельзя');
  }
  return a / b;
}
