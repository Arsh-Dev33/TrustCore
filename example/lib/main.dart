import 'package:flutter/material.dart';
import 'package:trust_core/trust_core.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustCore Example',
      theme: ThemeData.dark(),
      home: const ExampleHome(),
    );
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});
  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  final _tc = TrustCore();
  String _result = 'Tap a button to start';
  String? _storedBase64;

  Future<void> _signup() async {
    final r = await _tc.signup(context: context, userId: 'demo_user');
    setState(() {
      if (r.success) {
        _storedBase64 = r.imageBase64;
        _result = '✅ Signup OK | txn: ${r.transactionId}';
      } else {
        _result = '❌ ${r.error} | ${r.message}';
      }
    });
  }

  Future<void> _verify() async {
    final r = await _tc.verify(
      context: context,
      userId: 'demo_user',
      referenceImageBase64: _storedBase64!,
    );
    setState(() {
      _result = r.passed
          ? '✅ ${r.matchPercent.toStringAsFixed(1)}% ${r.verdict} | txn: ${r.transactionId}'
          : '❌ ${r.matchPercent.toStringAsFixed(1)}% ${r.verdict} | ${r.error}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TrustCore Example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(_result, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: _signup, child: const Text('Signup')),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _storedBase64 != null ? _verify : null,
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
  }
}
