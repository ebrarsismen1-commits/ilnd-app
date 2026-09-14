import 'package:flutter/material.dart';
import 'package:ilnd_app/core/theme/app_palette.dart';
import 'package:ilnd_app/core/widgets/island_artwork.dart';
import 'package:ilnd_app/features/adan/adan_model.dart';

/// The same server-owned island state is rendered on Home and Adan.
/// This adapter makes no earning decisions and performs no network writes.
class IslandScene extends StatelessWidget {
  const IslandScene({
    super.key,
    required this.state,
    required this.p,
    this.contentPadding = EdgeInsets.zero,
  });

  final IslandState state;
  final AppPalette p;
  final EdgeInsets contentPadding;

  @override
  Widget build(BuildContext context) => IslandArtwork(
    p: p,
    earned: state.earned,
    waterDepth: state.water.index,
    contentPadding: contentPadding,
  );
}
