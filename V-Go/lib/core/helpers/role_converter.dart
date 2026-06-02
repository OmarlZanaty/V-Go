String roleConverter(String? role) {
  switch (role) {
    case 'Client':
      return 'عميل';
    case 'Driver':
      return 'سائق';
    case 'Dispatcher':
      return 'موزع';
    case 'Accountant':
      return 'محاسب';
  }
  return 'غير معروف';
}
