enum Pet {
  dog('Собака'),
  cat('Кошка'),
  bird('Птица');

  const Pet(this.localization);
  final String localization;

  void _printPetName() {
    print(this.localization);
  }
}

void main() {
  final vasyaPet = Pet.dog;
  final stasPet = Pet.cat;
  final mishaPet = Pet.bird;

  vasyaPet._printPetName();
  stasPet._printPetName();
  mishaPet._printPetName();
}
