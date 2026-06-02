class AllExpensesResponseModel {
  final num totalExpenses;
  final List<ExpenseItemModel> expenses;

  AllExpensesResponseModel({
    required this.totalExpenses,
    required this.expenses,
  });

  factory AllExpensesResponseModel.fromJson(Map<String, dynamic> json) {
    return AllExpensesResponseModel(
      totalExpenses: json['totalExpenses'] as num,
      expenses: (json['expenses'] as List<dynamic>)
          .map((e) => ExpenseItemModel.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  AllExpensesResponseModel copyWith({
    num? totalExpenses,
    List<ExpenseItemModel>? expenses,
  }) {
    return AllExpensesResponseModel(
      totalExpenses: totalExpenses ?? this.totalExpenses,
      expenses: expenses ?? List<ExpenseItemModel>.from(this.expenses),
    );
  }
}

class ExpenseItemModel {
  final String id;
  final String description;
  final num cost;
  final DateTime date;

  ExpenseItemModel({
    required this.id,
    required this.description,
    required this.cost,
    required this.date,
  });

  factory ExpenseItemModel.fromJson(Map<String, dynamic> json) {
    return ExpenseItemModel(
      id: json['id'] as String,
      description: json['description'] as String,
      cost: json['cost'] as num,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
