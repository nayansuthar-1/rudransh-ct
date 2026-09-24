import '../../data/models/models.dart';
import 'razorpay_result.dart';

export 'razorpay_result.dart';

/// Tests and non-web builds: the demo repository takes the place of the
/// gateway, so the "payment" succeeds at once with a stand-in signature.
Future<RazorpayResult?> openRazorpayCheckout(OnlineOrder order) async =>
    RazorpayResult(
      orderId: order.orderId,
      paymentId: 'pay_demo_${order.orderId}',
      signature: 'demo',
    );
