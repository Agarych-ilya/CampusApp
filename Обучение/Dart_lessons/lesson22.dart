void main() {
  final wolf = Wolf(5);
  final tiger = Tiger(1);

  wolf.makeSound();
  tiger.makePerfomanceInCircus();

  print(wolf.age);
}

abstract interface class Animal {
  double get age;
  void makeSound();
}

class Wolf implements Animal {
  Wolf(this.age);
  @override
  void makeSound() {
    print('voice_wolf');
  }

  @override
  final double age;
}

class Tiger implements Animal {
  Tiger(this.age);
  @override
  void makeSound() {
    print('voice_tiger');
  }

  void makePerfomanceInCircus() {
    print('tiger in circus');
  }

  @override
  final double age;
}
