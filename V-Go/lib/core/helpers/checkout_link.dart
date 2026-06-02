String getCheckoutLink({
  required String clientSecret,
  required String publicKey,
}) {
  final String link =
      'https://accept.paymob.com/unifiedcheckout/?publicKey=$publicKey&clientSecret=$clientSecret';
  return link;
}
