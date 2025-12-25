void main() {
  final storage = Storage<String>(value: 'ffffff');
  print(storage.read());
  storage.update('dddd');
  final str = storage.read();
  print(str);
}

//String? _getBoxOfEggs() {
//return null;
//}

class Storage<T> {
  Storage({this.value});
  T? value;

  T? read() => value;

  void update(T? value) {
    this.value = value;
  }
}
