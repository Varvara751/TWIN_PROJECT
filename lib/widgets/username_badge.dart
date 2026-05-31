import 'package:flutter/material.dart';

import '../services/social_service.dart';

class UsernameBadge extends StatelessWidget {
  const UsernameBadge({
    super.key,
    required this.username,
    this.onTap,
    this.compact = false,
  });

  final Object? username;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = SocialService.instance.usernameLabel(username);
    final badge = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.pink.shade50,
        border: Border.all(color: Colors.pink.shade100),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 3 : 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.alternate_email,
              size: compact ? 13 : 15,
              color: Colors.pink.shade600,
            ),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label.replaceFirst('@', ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.pink.shade700,
                  fontSize: compact ? 12 : 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) return badge;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: badge,
    );
  }
}
