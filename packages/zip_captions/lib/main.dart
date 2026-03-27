// Minimal app stub — replaced in Unit 3.
import 'package:flutter/material.dart';

void main() {
  runApp(const _App());
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Zip Captions',
      home: Scaffold(
        body: Center(
          child: Text('Zip Captions'),
        ),
      ),
    );
  }
}
