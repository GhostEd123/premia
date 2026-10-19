import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/film.dart';

/// Bottom sheet with the full film information ("View details").
class FilmDetailsSheet extends StatelessWidget {
  const FilmDetailsSheet({required this.film, super.key});

  final Film film;

  static Future<void> show(BuildContext context, Film film) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FilmDetailsSheet(film: film),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          const SheetHeader(),
          Text(film.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          if ((film.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(film.description!, style: const TextStyle(color: AppColors.textSecondary, height: 1.4)),
          ],
          if (film.directors.isNotEmpty) _Section(title: 'Directors', body: film.directors.join(' • ')),
          if (film.cast.isNotEmpty) _Section(title: 'Cast', body: film.cast.join(' • ')),
          if ((film.genre ?? '').isNotEmpty) _Section(title: 'Genre', body: film.genre!),
          if ((film.studio ?? '').isNotEmpty) _Section(title: 'Studio', body: film.studio!),
          if (film.durationMinutes != null)
            _Section(title: 'Runtime', body: Formatters.runtime(film.durationMinutes!)),
          const _Section(title: 'Viewing Rights', body: _viewingRights),
        ],
      ),
    );
  }
}

const String _viewingRights =
    'Each Premia ticket gives you access to one premiere during its premiere '
    'window. You can start watching any time after the premiere goes live, '
    'until the window closes. You can’t skip ahead of the premiere’s live '
    'point. You can rewind up to 10 minutes behind the furthest point you’ve '
    'watched. Once the window closes, the premiere is no longer available.';

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5)),
        ],
      ),
    );
  }
}
