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
  String _result = 'Tap to verify face';

  Future<void> _verify() async {
    final result = await TrustCore.capture(context);

    if (result != null) {
      setState(() {
        _result =
            '✅ Success!\n\n'
            'Lat: ${result.latitude}\n'
            'Lng: ${result.longitude}\n'
            'Captured at: ${result.capturedAt}\n'
            'Base64 chars: ${result.base64Image.length}';
      });
    } else {
      setState(() {
        _result = '❌ User cancelled or verification failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TrustCore Example')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _result,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _verify,
                child: const Text('Verify Face'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
