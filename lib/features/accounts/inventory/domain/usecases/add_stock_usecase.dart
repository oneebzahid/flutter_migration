import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/inventory_repository.dart';

class AddStockParams extends Equatable {
  const AddStockParams({
    required this.productId,
    required this.serials,
    required this.serialCities,
    required this.sellPrice,
    required this.costPrice,
  });

  final String productId;
  final List<String> serials;
  final Map<String, String> serialCities;
  final double sellPrice;
  final double costPrice;

  @override
  List<Object?> get props => [
    productId,
    serials,
    serialCities,
    sellPrice,
    costPrice,
  ];
}

/// One action: addStock.
class AddStockUseCase implements UseCase<Unit, AddStockParams> {
  AddStockUseCase(this._repository);

  final InventoryRepository _repository;

  @override
  Future<Either<Failure, Unit>> call(AddStockParams params) =>
      _repository.addStock(
        productId: params.productId,
        serials: params.serials,
        serialCities: params.serialCities,
        sellPrice: params.sellPrice,
        costPrice: params.costPrice,
      );
}
