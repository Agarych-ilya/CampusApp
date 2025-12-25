import 'dart:io';

void main() {
  // считываем данные
  int n = int.parse(stdin.readLineSync()!);
  // вывод данных
  print(isSimple(n + 1));
}

int isSimple(int number) {
  int count = 0;
  for (int i = 1; i <= number; i++) {
    if (number % i == 0) {
      count++;
    }
  }
  if (count != 2) {
    return isSimple(number + 1);
  } else {
    return number;
  }
}
