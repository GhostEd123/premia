import 'waitlist_repository.dart';

/// Submits an email or phone number to the waitlist lead capture endpoint.
class SubmitWaitlist {
  const SubmitWaitlist(this._repository);
  final WaitlistRepository _repository;

  Future<String> call({String? email, String? phone}) =>
      _repository.submitWaitlist(email: email, phone: phone);
}

