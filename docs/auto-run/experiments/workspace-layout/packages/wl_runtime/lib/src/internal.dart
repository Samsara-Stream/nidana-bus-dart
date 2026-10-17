// The same pattern the plugin flags, in a member that does not enable it.
class Bus {
  static final Bus instance = Bus();
}

Bus useGlobal() => Bus.instance;
