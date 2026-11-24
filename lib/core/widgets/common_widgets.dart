import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Premia wordmark displayed in headers.
class PremiaLogo extends StatelessWidget {
  const PremiaLogo({this.height = 28, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/Premia_wordmark.png',
      height: height,
      fit: BoxFit.contain,
      semanticLabel: 'Premia',
    );
  }
}

/// Drag handle + close button row shown at the top of bottom sheets.
class SheetHeader extends StatelessWidget {
  const SheetHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}

/// Network poster with a dark placeholder while loading / on failure.
class PosterImage extends StatelessWidget {
  const PosterImage({required this.url, this.fit = BoxFit.cover, super.key});

  final String? url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: AppColors.surfaceHigh,
      alignment: Alignment.center,
      child: const Icon(Icons.movie_outlined, color: AppColors.textMuted, size: 48),
    );
    final u = url;
    if (u == null || u.isEmpty) return placeholder;
    return Image.network(
      u,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
      errorBuilder: (context, error, stack) => placeholder,
    );
  }
}

/// Rebuilds every second with the time remaining until [target].
class CountdownBuilder extends StatelessWidget {
  const CountdownBuilder({required this.target, required this.builder, super.key});

  final DateTime target;
  final Widget Function(BuildContext context, Duration remaining) builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
      initialData: DateTime.now(),
      builder: (context, snapshot) {
        final remaining = target.difference(snapshot.data ?? DateTime.now());
        return builder(context, remaining.isNegative ? Duration.zero : remaining);
      },
    );
  }
}
