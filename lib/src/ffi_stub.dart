/// Stub for dart:ffi
library;

class Pointer<T> {
  const Pointer.fromAddress(int address);
  int get address => 0;
}

class Char {}
class Float {}
class Uint8 {}
class Allocator {}

class DynamicLibrary {
  static DynamicLibrary open(String path) => DynamicLibrary();
}

final Pointer<Never> nullptr = Pointer<Never>.fromAddress(0);
