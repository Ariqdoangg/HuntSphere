import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

/// Example of using Lottie animations
class LottieAnimationExample extends StatelessWidget {
  const LottieAnimationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lottie Animation Example')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Loading animation
            Lottie.asset(
              'assets/animations/loading.json',
              width: 200,
              height: 200,
              animate: true,
            ),
            const SizedBox(height: 20),
            const Text('Loading Animation'),
          ],
        ),
      ),
    );
  }
}

/// Example of using Shimmer effect
class ShimmerExample extends StatelessWidget {
  const ShimmerExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shimmer Effect Example')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Shimmer effect for text
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: const Text(
                'Loading content...',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 20),
            
            // Shimmer effect for card
            Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                width: double.infinity,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Combined example with both Lottie and Shimmer
class CombinedAnimationExample extends StatefulWidget {
  const CombinedAnimationExample({super.key});

  @override
  State<CombinedAnimationExample> createState() => _CombinedAnimationExampleState();
}

class _CombinedAnimationExampleState extends State<CombinedAnimationExample> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Simulate loading
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Combined Animation Example')),
      body: Center(
        child: _isLoading
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Lottie loading animation
                  Lottie.asset(
                    'assets/animations/loading.json',
                    width: 150,
                    height: 150,
                  ),
                  const SizedBox(height: 20),
                  // Shimmer placeholder
                  Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: 200,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              )
            : const Text(
                'Content Loaded!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
      ),
    );
  }
}
