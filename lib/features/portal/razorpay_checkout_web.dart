import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import '../../data/models/models.dart';
import 'razorpay_result.dart';

export 'razorpay_result.dart';

/// Razorpay's Standard Checkout, loaded only when a member first pays.
@JS('Razorpay')
extension type _Razorpay._(JSObject _) implements JSObject {
  external factory _Razorpay(JSObject options);
  external void open();
}

Future<void>? _loading;

Future<void> _loadScript() => _loading ??= () {
      final done = Completer<void>();
      final script = web.document.createElement('script') as web.HTMLScriptElement
        ..src = 'https://checkout.razorpay.com/v1/checkout.js'
        ..async = true;
      script.onload = ((web.Event _) => done.complete()).toJS;
      script.onerror = ((web.Event _) {
        // Let the next tap try again, e.g. after the network comes back.
        _loading = null;
        done.completeError(
          StateError('Could not open the payment page. Check the connection.'),
        );
      }).toJS;
      web.document.head!.append(script);
      return done.future;
    }();

/// Opens Razorpay's checkout for [order]. Completes with the payment when the
/// member pays, or null when they close the window without paying. A failed
/// attempt keeps the window open so they can try another way to pay.
Future<RazorpayResult?> openRazorpayCheckout(OnlineOrder order) async {
  await _loadScript();
  final done = Completer<RazorpayResult?>();

  final options = <String, Object?>{
    'key': order.keyId,
    'amount': order.amountPaise,
    'currency': order.currency,
    'name': order.name,
    'description': order.description,
    'order_id': order.orderId,
    'prefill': {
      'name': order.prefillName,
      'email': order.prefillEmail,
      'contact': order.prefillContact,
    },
    'theme': {'color': '#0B57D0'},
  }.jsify()! as JSObject;

  String field(JSObject response, String name) =>
      (response.getProperty<JSString?>(name.toJS))?.toDart ?? '';

  options.setProperty(
    'handler'.toJS,
    ((JSObject response) {
      if (done.isCompleted) return;
      done.complete(RazorpayResult(
        orderId: field(response, 'razorpay_order_id'),
        paymentId: field(response, 'razorpay_payment_id'),
        signature: field(response, 'razorpay_signature'),
      ));
    }).toJS,
  );

  final modal = JSObject()
    ..setProperty(
      'ondismiss'.toJS,
      (() {
        if (!done.isCompleted) done.complete(null);
      }).toJS,
    );
  options.setProperty('modal'.toJS, modal);

  _Razorpay(options).open();
  return done.future;
}
