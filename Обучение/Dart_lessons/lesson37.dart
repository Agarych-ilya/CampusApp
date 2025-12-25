import 'dart:math';

void main() async {
  final sec1 = await makeCoffee(1);
  final sec2 = await makeCoffee(2);
  final sec3 = await makeCoffee(3);
  print("$sec1, $sec2, $sec3");
  print(sec1 + sec3 + sec2);

  //await Future.wait([makeCoffee(1), makeCoffee(2), makeCoffee(3)]);
  //print('end');
}

Future<int> makeCoffee(int number) async {
  print("making coffee №$number");
  final random = Random();
  final seconds = random.nextInt(4) + 1;
  await Future.delayed(Duration(seconds: seconds));
  print("coffee №$number is done for $seconds seconds");
  return seconds;
}
