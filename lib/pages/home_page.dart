import 'package:flutter/material.dart';

import '../site_content_service.dart';
import '../widgets/profile_view.dart';

/// Home — the first page of Know N1SK, styled like an X profile screen.
///
/// The whole screen is the shared [ProfileView] (cover, avatar, name,
/// username, bio, updated-on, views, tabs) fed by the site content from
/// Firestore (`admin/site` via [SiteContentState]). Until content exists,
/// the approved placeholder art + text are shown. Content is edited on
/// `/admin-editor` and published live.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<SiteContent?>(
        valueListenable: SiteContentState.instance.content,
        builder: (context, content, _) => ProfileView(content: content),
      ),
    );
  }
}
