import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/error_handler.dart';
import 'facilitator_dashboard.dart';

class FacilitatorAuthScreen extends StatefulWidget {
  const FacilitatorAuthScreen({super.key});

  @override
  State<FacilitatorAuthScreen> createState() => _FacilitatorAuthScreenState();
}

class _FacilitatorAuthScreenState extends State<FacilitatorAuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _showPendingApprovalDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 64),
            SizedBox(height: 16),
            Text(
              'Pending Approval',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: const Text(
          'Your registration is pending admin approval. You will be notified once your account is approved.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Supabase.instance.client.auth.signOut();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: Colors.black,
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.block, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(color: Colors.white, fontSize: 20),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        content: const Text(
          'Your registration has been rejected. Please contact the administrator for more information.',
          style: TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Supabase.instance.client.auth.signOut();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        // Check if facilitator is approved
        final facilitator = await Supabase.instance.client
            .from('facilitators')
            .select('status, is_admin')
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
            .maybeSingle();

        if (mounted) {
          if (facilitator == null) {
            // No facilitator record - create one as pending
            try {
              await Supabase.instance.client.from('facilitators').insert({
                'user_id': Supabase.instance.client.auth.currentUser!.id,
                'name': _emailController.text.split('@').first,
                'email': _emailController.text.trim(),
                'organization': 'Pending',
                'status': 'pending',
                'is_admin': false,
              });
            } catch (insertError) {
              debugPrint('Failed to create facilitator record: $insertError');
            }
            _showPendingApprovalDialog();
          } else if (facilitator['status'] == 'pending') {
            _showPendingApprovalDialog();
          } else if (facilitator['status'] == 'rejected') {
            _showRejectedDialog();
          } else {
            // Approved - go to dashboard
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const FacilitatorDashboard()),
            );
          }
        }
      } else {
        // Registration
        await Supabase.instance.client.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          data: {'name': _nameController.text.trim()},
        );

        // Create facilitator record with PENDING status
        await Supabase.instance.client.from('facilitators').insert({
          'user_id': Supabase.instance.client.auth.currentUser!.id,
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'organization': 'Pending',
          'status': 'pending',
          'is_admin': false,
        });

        if (mounted) {
          _showPendingApprovalDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return EliteScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTheme.spacingL),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnimation.value),
                    child: child,
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios),
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),

                  // Logo
                  const EliteLogo(size: 100),
                  const SizedBox(height: AppTheme.spacingL),

                  // Title
                  const GradientText(
                    text: 'HuntSphere',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXS),

                  // Subtitle
                  Text(
                    'Facilitator Portal',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingXL),

                  // Tab switcher
                  EliteTabSwitcher(
                    tabs: const ['Login', 'Register'],
                    selectedIndex: _isLogin ? 0 : 1,
                    onTabSelected: (index) {
                      setState(() => _isLogin = index == 0);
                    },
                  ),
                  const SizedBox(height: AppTheme.spacingXL),

                  // Form
                  _buildForm(),
                  const SizedBox(height: AppTheme.spacingL),

                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: EliteButton(
                      onPressed: _handleAuth,
                      label: _isLogin ? 'Login' : 'Create Account',
                      isLoading: _isLoading,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingL),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          // Name field (only for register)
          if (!_isLogin) ...[
            EliteTextField(
              controller: _nameController,
              label: 'Full Name',
              prefixIcon: Icons.person_outline,
              validator: Validators.validateName,
            ),
            const SizedBox(height: AppTheme.spacingM),
          ],

          // Email field
          EliteTextField(
            controller: _emailController,
            label: 'Email',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: Validators.validateEmail,
          ),
          const SizedBox(height: AppTheme.spacingM),

          // Password field
          EliteTextField(
            controller: _passwordController,
            label: 'Password',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textMuted,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
            validator: Validators.validatePassword,
          ),
        ],
      ),
    );
  }
}
