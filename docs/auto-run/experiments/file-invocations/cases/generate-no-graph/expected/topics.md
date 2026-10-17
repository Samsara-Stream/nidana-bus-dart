<!-- GENERATED CODE - DO NOT MODIFY BY HAND. -->
<!-- nidana_dart_codegen from topics.yaml (topic-codegen@v1). -->

# Topic catalog

19 topics in 5 domains, from `topics.yaml`. No topology graph was given, so readers and writers are not listed.

| Domain | Owner | Registry | Topics |
| --- | --- | --- | --- |
| `auth` | platform-team | `AuthTopics` | 3 |
| `checkout` | payments-team | `CheckoutTopics` | 5 |
| `payment` | payments-team | `PaymentTopics` | 3 |
| `settings` | mobile-platform (Jakarta) | `SettingsTopics` | 7 |
| `profile` | platform-team | `ProfileTopics` | 1 |

## Domain `auth`

Owner: platform-team. Registry: `AuthTopics`.

### `auth.state`

Current authentication state.

| Property | Value |
| --- | --- |
| Member | `AuthTopics.state` |
| Variant | state |
| Type | `AuthState` |
| Initial | `const AuthState.initializing()` |
| Dedup | equality |
| Sensitive | yes |
| Tracing | enabled |

### `auth.login-event`

Credentials a login form submits, as a `LoginCredentials` value.

Never logged: the topic is `sensitive`, so an observer needs `observeSensitive`.

| Property | Value |
| --- | --- |
| Member | `AuthTopics.loginEvent` |
| Variant | event |
| Type | `LoginCredentials` |
| Sensitive | yes |
| Tracing | enabled |

### `auth.token.refresh`

| Property | Value |
| --- | --- |
| Member | `AuthTopics.tokenRefresh` |
| Variant | event |
| Type | `TokenRefresh` |
| Sensitive | no |
| Tracing | disabled |

## Domain `checkout`

Owner: payments-team. Registry: `CheckoutTopics`.

### `checkout.cart-events`

| Property | Value |
| --- | --- |
| Member | `CheckoutTopics.cartEvents` |
| Variant | event |
| Type | `CartEvent` |
| Sensitive | no |
| Tracing | enabled |

### `checkout.cart-items`

| Property | Value |
| --- | --- |
| Member | `CheckoutTopics.cartItems` |
| Variant | state |
| Type | `CartItems` |
| Initial | `CartItems.empty` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `checkout.submit-order`

| Property | Value |
| --- | --- |
| Member | `CheckoutTopics.submitOrder` |
| Variant | event |
| Type | `SubmitOrder` |
| Sensitive | no |
| Tracing | enabled |

### `checkout.ui-state`

What the checkout page renders, rebuilt on every cart or auth change.

| Property | Value |
| --- | --- |
| Member | `CheckoutTopics.uiState` |
| Variant | state |
| Type | `CheckoutUi` |
| Initial | `const CheckoutUi.idle()` |
| Dedup | none |
| Sensitive | no |
| Tracing | enabled |

### `checkout.recent-orders`

The 8 most recent orders, each a `List<OrderSummary>` page; replays to late subscribers (buffer \> 1).

| Property | Value |
| --- | --- |
| Member | `CheckoutTopics.recentOrders` |
| Variant | replay |
| Type | `List<OrderSummary>` |
| Buffer size | 8 |
| Sensitive | no |
| Tracing | enabled |

## Domain `payment`

Owner: payments-team. Registry: `PaymentTopics`.

### `payment.result`

| Property | Value |
| --- | --- |
| Member | `PaymentTopics.result` |
| Variant | state |
| Type | `PaymentResult` |
| Initial | `const PaymentResult.none()` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `payment.sdk-state`

| Property | Value |
| --- | --- |
| Member | `PaymentTopics.sdkState` |
| Variant | state |
| Type | `PaymentSdkState` |
| Initial | `PaymentSdkState.disconnected` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `payment.ui-state`

| Property | Value |
| --- | --- |
| Member | `PaymentTopics.uiState` |
| Variant | state |
| Type | `PaymentUi` |
| Initial | `const PaymentUi()` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

## Domain `settings`

Owner: mobile-platform (Jakarta). Registry: `SettingsTopics`.

### `settings.theme`

| Property | Value |
| --- | --- |
| Member | `SettingsTopics.theme` |
| Variant | state |
| Type | `Theme` |
| Initial | `Theme.system` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `settings.theme-requested`

| Property | Value |
| --- | --- |
| Member | `SettingsTopics.themeRequested` |
| Variant | event |
| Type | `Theme` |
| Sensitive | no |
| Tracing | enabled |

### `settings.launch-count`

| Property | Value |
| --- | --- |
| Member | `SettingsTopics.launchCount` |
| Variant | state |
| Type | `int` |
| Initial | `0` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `settings.font-scale`

| Property | Value |
| --- | --- |
| Member | `SettingsTopics.fontScale` |
| Variant | state |
| Type | `double` |
| Initial | `1.0` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `settings.onboarded`

| Property | Value |
| --- | --- |
| Member | `SettingsTopics.onboarded` |
| Variant | state |
| Type | `bool` |
| Initial | `false` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `settings.banner`

| Property | Value |
| --- | --- |
| Member | `SettingsTopics.banner` |
| Variant | state |
| Type | `String` |
| Initial | ``'Try `nidana` \| beta'`` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

### `settings.flags`

| Property | Value |
| --- | --- |
| Member | `SettingsTopics.flags` |
| Variant | state |
| Type | `({bool beta, int level})` |
| Initial | `(beta: false, level: 0)` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |

## Domain `profile`

Owner: platform-team. Registry: `ProfileTopics`.

### `profile.avatar`

| Property | Value |
| --- | --- |
| Member | `ProfileTopics.avatar` |
| Variant | state |
| Type | `Uint8List?` |
| Initial | `null` |
| Dedup | equality |
| Sensitive | no |
| Tracing | enabled |
