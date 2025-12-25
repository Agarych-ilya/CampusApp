mixin Wifi {
  void enableWifi() {
    print("Wifi enabled");
  }

  void disableWifi() {
    print("Wifi disabled");
  }
}

class Phone with Wifi {}

class TV with Wifi {}

void main() {
  var xiaomi = Phone();
  xiaomi.enableWifi();
  xiaomi.disableWifi();
}
