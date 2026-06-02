class AddExpenseRequestModel {
  final num cost;
  final String description;

  AddExpenseRequestModel({
    required this.cost,
    required this.description,
  });

  Map<String, dynamic> toJson() {
    return {'cost': cost, 'description': description};
  }
}
