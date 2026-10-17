class Bus {
  static final Bus instance = Bus();
}

Bus useGlobal() => Bus.instance;
