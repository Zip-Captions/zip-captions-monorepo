// Lightweight PBT helper replacing glados (incompatible with Dart 3).
//
// Provides Generator<T>, the `any` namespace, and the Glados runner.
// Each Glados.test() runs the body 100 times with seeded Random instances
// so failures are reproducible.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart' as ft;

typedef Generator<T> = T Function(Random random);

final _AnyGenerators any = _AnyGenerators();

class _AnyGenerators {
  Generator<T> choose<T>(List<T> choices) =>
      (r) => choices[r.nextInt(choices.length)];

  Generator<bool> get boolGen => (r) => r.nextBool();

  Generator<String> get letterOrDigits => (r) {
        const chars =
            'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        final len = r.nextInt(20);
        return String.fromCharCodes(
          List.generate(len, (_) => chars.codeUnitAt(r.nextInt(chars.length))),
        );
      };

  Generator<int> intInRange(int min, int max) =>
      (r) => min + r.nextInt(max - min);

  Generator<double> doubleInRange(double min, double max) =>
      (r) => min + r.nextDouble() * (max - min);

  Generator<T> combine2<A, B, T>(
    Generator<A> g1,
    Generator<B> g2,
    T Function(A, B) fn,
  ) =>
      (r) => fn(g1(r), g2(r));

  Generator<T> combine3<A, B, C, T>(
    Generator<A> g1,
    Generator<B> g2,
    Generator<C> g3,
    T Function(A, B, C) fn,
  ) =>
      (r) => fn(g1(r), g2(r), g3(r));

  Generator<T> combine4<A, B, C, D, T>(
    Generator<A> g1,
    Generator<B> g2,
    Generator<C> g3,
    Generator<D> g4,
    T Function(A, B, C, D) fn,
  ) =>
      (r) => fn(g1(r), g2(r), g3(r), g4(r));

  Generator<T> combine5<A, B, C, D, E, T>(
    Generator<A> g1,
    Generator<B> g2,
    Generator<C> g3,
    Generator<D> g4,
    Generator<E> g5,
    T Function(A, B, C, D, E) fn,
  ) =>
      (r) => fn(g1(r), g2(r), g3(r), g4(r), g5(r));

  Generator<T> combine6<A, B, C, D, E, F, T>(
    Generator<A> g1,
    Generator<B> g2,
    Generator<C> g3,
    Generator<D> g4,
    Generator<E> g5,
    Generator<F> g6,
    T Function(A, B, C, D, E, F) fn,
  ) =>
      (r) => fn(g1(r), g2(r), g3(r), g4(r), g5(r), g6(r));

  Generator<List<T>> listWithLengthInRange<T>(
    int min,
    int max,
    Generator<T> element,
  ) =>
      (r) => List.generate(min + r.nextInt(max - min + 1), (_) => element(r));
}

class Glados<T> {
  const Glados(this._generator);

  final Generator<T> _generator;

  static const int _trials = 100;

  void test(String description, dynamic Function(T) body) {
    ft.test(description, () async {
      for (var seed = 0; seed < _trials; seed++) {
        final value = _generator(Random(seed));
        await body(value);
      }
    });
  }
}
