import 'package:equatable/equatable.dart';

/// A film in the catalog. Optional fields are absent from list responses.
class Film extends Equatable {
  const Film({
    required this.id,
    required this.title,
    this.genre,
    this.description,
    this.durationMinutes,
    this.thumbnailUrl,
    this.ticketPriceNgn,
    this.premiereStart,
    this.premiereEnd,
    this.directors = const [],
    this.cast = const [],
    this.studio,
  });

  final String id;
  final String title;
  final String? genre;
  final String? description;

  /// Film runtime in minutes, as supplied by the backend (`duration`).
  final num? durationMinutes;
  final String? thumbnailUrl;
  final num? ticketPriceNgn;
  final DateTime? premiereStart;

  /// End of the premiere window ("doors close"); null if not supplied.
  final DateTime? premiereEnd;
  final List<String> directors;
  final List<String> cast;
  final String? studio;

  bool get hasPremiered {
    final start = premiereStart;
    return start != null && !start.isAfter(DateTime.now());
  }

  bool get isUpcoming {
    final start = premiereStart;
    return start != null && start.isAfter(DateTime.now());
  }

  @override
  List<Object?> get props => [
        id,
        title,
        genre,
        description,
        durationMinutes,
        thumbnailUrl,
        ticketPriceNgn,
        premiereStart,
        premiereEnd,
        directors,
        cast,
        studio,
      ];
}
