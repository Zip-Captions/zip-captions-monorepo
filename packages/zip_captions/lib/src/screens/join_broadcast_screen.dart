import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/screens/viewer_screen.dart';
import 'package:zip_captions/src/widgets/viewer_route_args.dart';
import 'package:zip_core/zip_core.dart';

/// The join-broadcast entry form (F-7.1).
///
/// Pure presentation: it parses the typed ID or URL with
/// [BroadcastLink.parseInput] and either shows the inline error copy or
/// navigates to the viewer with the parsed link. No transport, no session
/// state, no persistence.
class JoinBroadcastScreen extends ConsumerStatefulWidget {
  /// Creates the join screen.
  const JoinBroadcastScreen({super.key});

  /// The route path this screen is mounted at.
  static const routePath = '/join';

  @override
  ConsumerState<JoinBroadcastScreen> createState() =>
      _JoinBroadcastScreenState();
}

class _JoinBroadcastScreenState extends ConsumerState<JoinBroadcastScreen> {
  final _controller = TextEditingController();
  bool _valid = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = BroadcastLink.parseInput(_controller.text);
    if (parsed == null) {
      setState(() => _valid = false);
      return;
    }
    setState(() => _valid = true);
    context.goNamed(
      ViewerScreen.routeName,
      pathParameters: {'broadcastId': parsed.value},
      extra: ViewerRouteArgs(broadcastId: parsed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(zcStringsProvider).valueOrNull;
    if (strings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.joinBroadcastTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.go,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: strings.joinBroadcastFieldLabel,
                errorText: _valid ? null : strings.joinBroadcastInvalidInput,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submit,
              child: Text(strings.joinBroadcastSubmit),
            ),
          ],
        ),
      ),
    );
  }
}
