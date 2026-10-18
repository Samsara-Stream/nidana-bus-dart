// GENERATED CODE - DO NOT MODIFY BY HAND.
// nidana_dart_codegen from topics.yaml (topic-codegen@v1).

import 'dart:typed_data';

import 'package:example_app/auth/auth.dart';
import 'package:example_app/checkout/checkout.dart';
import 'package:example_app/settings/settings.dart';
import 'package:nidana_dart_contracts/nidana_dart_contracts.dart';

import 'payment/payment.dart';

/// Topics of the `auth` domain, owned by platform-team.
abstract final class AuthTopics {
  /// Current authentication state.
  static final StateTopic<AuthState> state = StateTopic<AuthState>(
    name: 'auth.state',
    initial: const AuthState.initializing(),
    sensitive: true,
  );

  /// Credentials a login form submits, as a `LoginCredentials` value.
  ///
  /// Never logged: the topic is `sensitive`, so an observer needs `observeSensitive`.
  static final EventTopic<LoginCredentials> loginEvent =
      EventTopic<LoginCredentials>(name: 'auth.login-event', sensitive: true);

  static final EventTopic<TokenRefresh> tokenRefresh = EventTopic<TokenRefresh>(
    name: 'auth.token.refresh',
    tracing: Tracing.disabled,
  );
}

/// Topics of the `checkout` domain, owned by payments-team.
abstract final class CheckoutTopics {
  static final EventTopic<CartEvent> cartEvents = EventTopic<CartEvent>(
    name: 'checkout.cart-events',
  );

  static final StateTopic<CartItems> cartItems = StateTopic<CartItems>(
    name: 'checkout.cart-items',
    initial: CartItems.empty,
  );

  static final EventTopic<SubmitOrder> submitOrder = EventTopic<SubmitOrder>(
    name: 'checkout.submit-order',
  );

  /// What the checkout page renders, rebuilt on every cart or auth change.
  static final StateTopic<CheckoutUi> uiState = StateTopic<CheckoutUi>(
    name: 'checkout.ui-state',
    initial: const CheckoutUi.idle(),
    dedup: Dedup.none,
  );

  /// The 8 most recent orders, each a `List<OrderSummary>` page; replays to late subscribers (buffer \> 1).
  static final ReplayTopic<List<OrderSummary>> recentOrders =
      ReplayTopic<List<OrderSummary>>(
        name: 'checkout.recent-orders',
        bufferSize: 8,
      );
}

/// Topics of the `payment` domain, owned by payments-team.
abstract final class PaymentTopics {
  static final StateTopic<PaymentResult> result = StateTopic<PaymentResult>(
    name: 'payment.result',
    initial: const PaymentResult.none(),
  );

  static final StateTopic<PaymentSdkState> sdkState =
      StateTopic<PaymentSdkState>(
        name: 'payment.sdk-state',
        initial: PaymentSdkState.disconnected,
      );

  static final StateTopic<PaymentUi> uiState = StateTopic<PaymentUi>(
    name: 'payment.ui-state',
    initial: const PaymentUi(),
  );
}

/// Topics of the `settings` domain, owned by mobile-platform (Jakarta).
abstract final class SettingsTopics {
  static final StateTopic<Theme> theme = StateTopic<Theme>(
    name: 'settings.theme',
    initial: Theme.system,
  );

  static final EventTopic<Theme> themeRequested = EventTopic<Theme>(
    name: 'settings.theme-requested',
  );

  static final StateTopic<int> launchCount = StateTopic<int>(
    name: 'settings.launch-count',
    initial: 0,
  );

  static final StateTopic<double> fontScale = StateTopic<double>(
    name: 'settings.font-scale',
    initial: 1.0,
  );

  static final StateTopic<bool> onboarded = StateTopic<bool>(
    name: 'settings.onboarded',
    initial: false,
  );

  static final StateTopic<String> banner = StateTopic<String>(
    name: 'settings.banner',
    initial: 'Try `nidana` | beta',
  );

  static final StateTopic<({bool beta, int level})> flags =
      StateTopic<({bool beta, int level})>(
        name: 'settings.flags',
        initial: (beta: false, level: 0),
      );
}

/// Topics of the `profile` domain, owned by platform-team.
abstract final class ProfileTopics {
  static final StateTopic<Uint8List?> avatar = StateTopic<Uint8List?>(
    name: 'profile.avatar',
    initial: null,
  );
}
