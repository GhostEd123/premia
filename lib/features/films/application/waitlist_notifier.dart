import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/validators.dart';
import '../domain/waitlist_repository.dart';
import '../domain/waitlist_use_cases.dart';

/// Bound to the data implementation in `lib/composition_root.dart`.
final waitlistRepositoryProvider = Provider<WaitlistRepository>(
  (ref) => throw UnimplementedError('waitlistRepositoryProvider not overridden'),
);

final submitWaitlistProvider = Provider(
  (ref) => SubmitWaitlist(ref.watch(waitlistRepositoryProvider)),
);

const Object _keep = Object();

class WaitlistState {
  const WaitlistState({
    this.emailError,
    this.isSubmitting = false,
    this.isSubmitted = false,
    this.successMessage,
    this.errorMessage,
  });

  final String? emailError;
  final bool isSubmitting;
  final bool isSubmitted;
  final String? successMessage;
  final String? errorMessage;

  WaitlistState copyWith({
    Object? emailError = _keep,
    bool? isSubmitting,
    bool? isSubmitted,
    Object? successMessage = _keep,
    Object? errorMessage = _keep,
  }) =>
      WaitlistState(
        emailError: emailError == _keep ? this.emailError : emailError as String?,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        isSubmitted: isSubmitted ?? this.isSubmitted,
        successMessage: successMessage == _keep
            ? this.successMessage
            : successMessage as String?,
        errorMessage: errorMessage == _keep
            ? this.errorMessage
            : errorMessage as String?,
      );
}

/// Waitlist form state (per visit).
class WaitlistNotifier extends Notifier<WaitlistState> {
  @override
  WaitlistState build() => const WaitlistState();

  Future<void> submit(String input) async {
    final trimmed = input.trim();
    final isPhone = RegExp(r'^\+?[0-9]{7,15}$').hasMatch(trimmed);
    final isEmail = Validators.email(trimmed) == null;

    if (!isPhone && !isEmail) {
      state = state.copyWith(
        emailError: 'Enter a valid email address or phone number.',
        isSubmitted: false,
      );
      return;
    }

    state = state.copyWith(
      emailError: null,
      isSubmitting: true,
      errorMessage: null,
    );

    try {
      final msg = await ref.read(submitWaitlistProvider)(
        email: isEmail ? trimmed : null,
        phone: isPhone ? trimmed : null,
      );
      state = state.copyWith(
        isSubmitting: false,
        isSubmitted: true,
        successMessage: msg,
      );
    } on ApiException catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
      );
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: 'Unable to join waitlist. Please try again.',
      );
    }
  }
}

final waitlistNotifierProvider =
    NotifierProvider.autoDispose<WaitlistNotifier, WaitlistState>(
  WaitlistNotifier.new,
);
