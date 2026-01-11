import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'facilitator_dashboard.dart';

class FacilitatorAuthScreen extends StatefulWidget {
  const FacilitatorAuthScreen({super.key});

  @override
  State<FacilitatorAuthScreen> createState() => _FacilitatorAuthScreenState();
}

class _FacilitatorAuthScreenState extends State<FacilitatorAuthScreen> {
  bool _isLogin = true;
  bool _isLoading = false;
  
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _organizationController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _organizationController.dispose();
    super.dispose();
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _login();
      } else {
        await _register();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _login() async {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (response.user == null) {
      throw Exception('Login failed');
    }

    // Check if facilitator is approved
    final facilData = await Supabase.instance.client
        .from('facilitators')
        .select()
        .eq('user_id', response.user!.id)
        .single();

    if (facilData['status'] != 'approved') {
      await Supabase.instance.client.auth.signOut();
      throw Exception('Your account is pending admin approval. Please wait for approval email.');
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const FacilitatorDashboard(),
        ),
      );
    }
  }

  Future<void> _register() async {
    // Register with Supabase Auth
    final response = await Supabase.instance.client.auth.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (response.user == null) {
      throw Exception('Registration failed');
    }

    // Create facilitator record (pending approval)
    await Supabase.instance.client.from('facilitators').insert({
      'user_id': response.user!.id,
      'email': _emailController.text.trim(),
      'name': _nameController.text.trim(),
      'organization': _organizationController.text.trim(),
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });

    // Sign out immediately (must wait for approval)
    await Supabase.instance.client.auth.signOut();

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Registration Successful!'),
          content: const Text(
            'Your account has been created and is pending admin approval. '
            'You will receive an email once your account is approved. '
            'You can then login.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() => _isLogin = true);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const Icon(
                    Icons.location_city,
                    size: 80,
                    color: Color(0xFF00D9FF),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '🎯 HuntSphere',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00D9FF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Facilitator Portal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Toggle Login/Register
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2332),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AuthToggleButton(
                            label: 'Login',
                            isSelected: _isLogin,
                            onTap: () => setState(() => _isLogin = true),
                          ),
                        ),
                        Expanded(
                          child: _AuthToggleButton(
                            label: 'Register',
                            isSelected: !_isLogin,
                            onTap: () => setState(() => _isLogin = false),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Name (Register only)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person, color: Color(0xFF00D9FF)),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _organizationController,
                      decoration: const InputDecoration(
                        labelText: 'Organization/School',
                        hintText: 'e.g., UPSI',
                        prefixIcon: Icon(Icons.business, color: Color(0xFF00D9FF)),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email, color: Color(0xFF00D9FF)),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (!v.contains('@')) return 'Invalid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      prefixIcon: Icon(Icons.lock, color: Color(0xFF00D9FF)),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Info box for registration
                  if (!_isLogin)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D9FF).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF00D9FF).withValues(alpha: 0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF00D9FF), size: 20),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your account requires admin approval before you can login.',
                              style: TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (!_isLogin) const SizedBox(height: 16),

                  // Submit Button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleAuth,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D9FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : Text(
                              _isLogin ? 'Login' : 'Register',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthToggleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AuthToggleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00D9FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.black : Colors.white70,
          ),
        ),
      ),
    );
  }
}
