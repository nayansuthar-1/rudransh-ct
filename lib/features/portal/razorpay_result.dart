/// What Razorpay's checkout hands back after a successful payment. The server
/// checks [signature] before anything is recorded.
class RazorpayResult {
  const RazorpayResult({
    required this.orderId,
    required this.paymentId,
    required this.signature,
  });

  final String orderId;
  final String paymentId;
  final String signature;
}
