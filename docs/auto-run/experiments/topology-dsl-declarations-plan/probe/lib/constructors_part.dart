part of 'constructors.dart';

/// A stage class in a part file, as the stages are: not reported.
final class PartStage<T> extends Handle<T> {
  PartStage._(this.input) : super._();
  final Handle<T> input;
}
