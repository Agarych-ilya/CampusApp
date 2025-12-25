import 'dart:math';

void main() async {
  final finalSec = await makeCoffee(
    1,
  ).then((sec) => sec, onError: (err) => false);
  //print('Кофе подано за столик за $finalSec сек');
  print(finalSec);

  //final sec1 = await makeCoffee(1);
  //final sec2 = await makeCoffee(2);
  //final sec3 = await makeCoffee(3);
  //print("$sec1, $sec2, $sec3");
  //print(sec1 + sec3 + sec2);
}

Future<bool> makeCoffee(int number) async {
  //throw Exception('Закончился кофе');
  print("making coffee №$number");
  final random = Random();
  final seconds = random.nextInt(4) + 1;
  await Future.delayed(Duration(seconds: seconds));
  print("coffee №$number is done for $seconds seconds");
  return true;
}
