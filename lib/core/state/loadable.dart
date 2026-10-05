import 'package:equatable/equatable.dart';

enum LoadStatus { idle, loading, ready, failed }

/// A loadable list: status + items + error. Controllers hold these in `Rx`
/// fields (`Rx<Loadable<Product>>`) and replace the whole value on change.
class Loadable<T> extends Equatable {
  const Loadable({
    this.status = LoadStatus.idle,
    this.items = const [],
    this.error,
  });

  final LoadStatus status;
  final List<T> items;
  final String? error;

  bool get isLoading => status == LoadStatus.loading;

  /// First load (nothing to show yet): idle, or loading with no items.
  bool get isInitialLoading =>
      status == LoadStatus.idle ||
      (status == LoadStatus.loading && items.isEmpty);

  Loadable<T> copyWith({LoadStatus? status, List<T>? items, String? error}) =>
      Loadable<T>(
        status: status ?? this.status,
        items: items ?? this.items,
        error: error,
      );

  Loadable<T> loading() => copyWith(status: LoadStatus.loading);
  Loadable<T> ready(List<T> items) =>
      Loadable<T>(status: LoadStatus.ready, items: items);
  Loadable<T> failed(String message) =>
      copyWith(status: LoadStatus.failed, error: message);

  @override
  List<Object?> get props => [status, items, error];
}
