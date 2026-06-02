String getTripStatus(String status) {
  switch (status) {
    case 'Pending':
      return 'قيد الانتظار';
    case 'Accepted':
      return 'مقبولة';
    case 'Arrived':
      return 'وصل';
    case 'Completed':
      return 'مكتملة';
    case 'Canceled':
      return 'ملغية';
    case 'InProgress':
      return 'قيد التنفيذ';
    default:
      return 'غير معروف';
  }
}
