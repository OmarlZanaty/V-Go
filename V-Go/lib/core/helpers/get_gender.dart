String getGender(String? gender) {
    switch (gender) {
      case 'Male':
      case 'male':
        return 'ذكر';
      case 'Female':
      case 'female':
        return 'انثى';
      default:
        return 'غير محدد';
    }
  }