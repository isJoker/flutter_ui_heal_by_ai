import 'package:flutter/material.dart';
import 'components/app_button.dart';
import 'components/user_card.dart';
import 'components/metric_badge.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Golden Test UI Self-Healing Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatelessWidget {
  const DemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UI Self-Healing Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Components',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            // Button
            AppButton(text: 'Primary Action', onPressed: () {}),
            const SizedBox(height: 16),
            AppButton(
              text: 'Secondary',
              variant: ButtonVariant.secondary,
              onPressed: () {},
            ),
            const SizedBox(height: 32),
            // UserCard
            const UserCard(
              name: 'Zhang San',
              email: 'zhangsan@example.com',
              avatarColor: Colors.blue,
            ),
            const SizedBox(height: 24),
            // MetricBadge
            const Wrap(
              spacing: 12,
              children: [
                MetricBadge(label: 'SSIM', value: '0.9812', status: MetricStatus.warning),
                MetricBadge(label: 'Pixels', value: '0', status: MetricStatus.pass),
                MetricBadge(label: 'Layout', value: 'OK', status: MetricStatus.pass),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
