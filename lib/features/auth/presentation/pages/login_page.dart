import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/company_config.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/theme/app_breakpoints.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/validation/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../core/widgets/app_dialog.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../controllers/auth_controller.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key, this.company = CompanyConfig.bullion});

  final CompanyConfig company;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ResponsiveBuilder(
        builder: (context, size) {
          final form = Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                // Flat card: the border does the separation (no heavy shadow).
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl + 4),
                    child: _LoginForm(
                      company: company,
                      showBrandHeader: size != ScreenSize.expanded,
                    ),
                  ),
                ),
              ),
            ),
          );
          if (size != ScreenSize.expanded) return SafeArea(child: form);
          return Row(
            children: [
              Expanded(flex: 5, child: _BrandPanel(company: company)),
              Expanded(
                flex: 4,
                child: ColoredBox(color: AppColors.background, child: form),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.company});
  final CompanyConfig company;

  static const _features = [
    (
      Icons.shield_outlined,
      'Secure access',
      'Role and screen based permissions',
    ),
    (
      Icons.bar_chart,
      'Financial reporting',
      'Balance sheet, income and bank activity',
    ),
    (
      Icons.account_tree_outlined,
      'Branch monitoring',
      'One view across every branch',
    ),
    (
      Icons.monitor_heart_outlined,
      'Live operations',
      'Inventory, invoices and ledger together',
    ),
  ];

  static Widget _ring(double size, double alpha) => ExcludeSemantics(
    child: IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.accent.withValues(alpha: alpha),
            width: 36,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      _content(context),
      Positioned(right: -120, top: -120, child: _ring(340, 0.10)),
      Positioned(left: -90, bottom: -150, child: _ring(300, 0.07)),
    ],
  );

  Widget _content(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sidebar, AppColors.gradientEnd],
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BrandLogo(size: 96),
              const SizedBox(height: AppSpacing.xl),
              Text(
                company.nameLine1,
                style: t.headlineMedium?.copyWith(
                  color: Colors.white,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                company.nameLine2,
                style: t.titleLarge?.copyWith(
                  color: AppColors.accent,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                company.tagline,
                style: t.titleMedium?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                company.description,
                style: t.bodyLarge?.copyWith(color: AppColors.textDisabled),
              ),
              const SizedBox(height: AppSpacing.xxl),
              for (final (icon, title, sub) in _features)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Icon(icon, size: 20, color: AppColors.accent),
                      ),
                      const SizedBox(width: AppSpacing.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: t.titleSmall?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              sub,
                              style: t.bodySmall?.copyWith(
                                color: AppColors.textDisabled,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.company, required this.showBrandHeader});

  final CompanyConfig company;
  final bool showBrandHeader;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _showPassword = false;
  final AuthController _auth = Get.find<AuthController>();
  Worker? _statusWorker;

  @override
  void initState() {
    super.initState();
    _statusWorker = ever<AuthStatus>(_auth.status, (s) {
      if (s == AuthStatus.authenticated) {
        Get.offAllNamed(AppRoutes.dashboard);
      }
    });
  }

  @override
  void dispose() {
    _statusWorker?.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (_auth.status.value == AuthStatus.authenticating) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _auth.login(_email.text.trim(), _password.text);
  }

  Future<void> _forgot(BuildContext context) async {
    _auth.clearReset();
    await showDialog<void>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initialEmail: _email.text.trim()),
    );
    _auth.clearReset();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Obx(() {
      final isLoading = _auth.status.value == AuthStatus.authenticating;
      final error = _auth.error.value;
      return AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.showBrandHeader) ...[
                const Center(child: BrandLogo(size: 72)),
                const SizedBox(height: AppSpacing.md),
                Text(
                  widget.company.fullName,
                  style: t.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.company.tagline,
                  style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
              Text('Sign in', style: t.headlineMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Enter your credentials to continue.',
                style: t.bodyMedium?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              if (error != null) ...[
                _ErrorBanner(message: error, onDismiss: _auth.dismissError),
                const SizedBox(height: AppSpacing.lg),
              ],
              AppTextField(
                label: 'Email',
                required: true,
                controller: _email,
                enabled: !isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                prefixIcon: Icons.mail_outline,
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                label: 'Password',
                required: true,
                controller: _password,
                enabled: !isLoading,
                obscureText: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                prefixIcon: Icons.lock_outline,
                validator: Validators.requiredPassword,
                onSubmitted: (_) => _submit(),
                suffix: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _showPassword = !_showPassword),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : () => _forgot(context),
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Sign in',
                icon: Icons.arrow_forward,
                expand: true,
                isLoading: isLoading,
                onPressed: _submit,
              ),
              if (kDebugMode) ...[
                const SizedBox(height: AppSpacing.xl),
                const _DemoHint(),
              ],
            ],
          ),
        ),
      );
    });
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: AppColors.error),
            ),
          ),
          InkWell(
            onTap: onDismiss,
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.close, size: 18, color: AppColors.error),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Debug-only: tells the tester which mock accounts exist. Not compiled into release behaviour.
class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: AppColors.accentSoft,
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Text(
      'Demo mode (mock data)\n'
      'Admin: admin@demo.com / admin123\n'
      'User: user@demo.com / user123\n'
      'Also: pending@demo.com / pending123, rejected@demo.com / rejected123',
      style: Theme.of(context).textTheme.bodySmall,
    ),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});
  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final AuthController _auth = Get.find<AuthController>();
  late final _email = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final status = _auth.resetStatus.value;
      final error = _auth.resetError.value;
      final sent = status == ResetStatus.sent;
      final sending = status == ResetStatus.sending;
      return AppDialog(
        title: 'Reset password',
        actions: [
          AppButton(
            label: sent ? 'Close' : 'Cancel',
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
          if (!sent)
            AppButton(
              label: 'Send reset link',
              isLoading: sending,
              onPressed: () {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                _auth.sendPasswordReset(_email.text.trim());
              },
            ),
        ],
        child: sent
            ? Text(
                'Password reset email sent to ${_email.text.trim()}.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            : Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enter your account email and we will send a reset link.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      label: 'Email',
                      required: true,
                      controller: _email,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.mail_outline,
                      validator: Validators.email,
                      errorText: error,
                    ),
                  ],
                ),
              ),
      );
    });
  }
}
