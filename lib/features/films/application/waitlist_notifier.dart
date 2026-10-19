import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/validators.dart';

const Object _keep = Object();

class WaitlistState {
  const WaitlistState({this.emailError, this.isSubmitted = false});

  final String? emailError;
  final bool isSubmitted;

  WaitlistState copyWith({Object? emailError = _keep, bool? isSubmitted}) =>
      WaitlistState(
        emailError: emailError == _keep ? this.emailError : emailError as String?,
        isSubmitted: isSubmitted ?? this.isSubmitted,
      );
}

/// Waitlist form state (per visit).
///
/// TODO(waitlist): the Premia API documents no waitlist endpoint, so a valid
/// email is validated and acknowledged locally but NOT sent anywhere. Once an
/// endpoint exists, add a `JoinWaitlist` use case + repository method and call
/// it from [submit].
class WaitlistNotifier extends Notifier<WaitlistState> {
  @override
  WaitlistState build() => const WaitlistState();

  void submit(String email) {
    final error = Validators.email(email);
    state = state.copyWith(emailError: error, isSubmitted: error == null);
  }
}

final waitlistNotifierProvider =
    NotifierProvider.autoDispose<WaitlistNotifier, WaitlistState>(
  WaitlistNotifier.new,
);
