import 'package:flutter/material.dart';
import 'package:happy_news/domain/entities/community.dart';

class CommunityBadge extends StatelessWidget {
  const CommunityBadge({super.key, required this.community});

  final CommunityId community;

  @override
  Widget build(BuildContext context) {
    final comm = Community.findById(community);
    if (comm == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Color(comm.brandColorArgb).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Color(comm.brandColorArgb).withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Text(
        comm.shortName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Color(comm.brandColorArgb),
        ),
      ),
    );
  }
}
