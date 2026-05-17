import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/design_system/design_system.dart';
import '../../../../core/observability/analytics_service.dart';
import '../../../../core/router/app_router.dart';
import '../controllers/auth_provider.dart';
import '../utils/auth_error_mapper.dart';
import '../widgets/auth_center_logo.dart';
import '../widgets/auth_shell.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberLogin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final ds = ref.read(authDatasourceProvider);
      final remember = await ds.getRememberLogin();
      final rememberedEmail = await ds.getRememberedEmail();
      if (!mounted) return;
      setState(() {
        _rememberLogin = remember;
        if (rememberedEmail != null) {
          _emailController.text = rememberedEmail;
        }
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
      _emailController.text.trim(),
      _passwordController.text,
      rememberLogin: _rememberLogin,
    );

    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (user) async {
        if (user != null) {
          ref.read(analyticsServiceProvider).logAuthLogin(method: 'password');
          if (user.twoFactorEnabled) {
            try {
              await ref.read(authDatasourceProvider).sendOtp(user.id);
            } catch (_) {
              if (!mounted) return;
              showCasaSnackbar(
                context,
                message: 'Não foi possível enviar o código 2FA.',
                isError: true,
              );
              return;
            }
            if (!mounted) return;
            ref.read(pendingOtpProvider.notifier).state = true;
            context.go(AppRoutes.otpVerification);
          } else {
            ref.read(pendingOtpProvider.notifier).state = false;
            context.go(AppRoutes.dashboard);
          }
        } else {
          showCasaSnackbar(
            context,
            message: 'Nao foi possivel autenticar este usuario.',
            isError: true,
          );
        }
      },
      error: (error, __) => showCasaSnackbar(
        context,
        message: mapAuthError(error, fallback: 'Falha ao entrar.'),
        isError: true,
      ),
      loading: () {},
    );
  }

  Future<void> _signInWithGoogle() async {
    await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle(rememberLogin: _rememberLogin);
    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (user) async {
        if (user != null) {
          ref.read(analyticsServiceProvider).logAuthLogin(method: 'google');
          if (user.twoFactorEnabled) {
            try {
              await ref.read(authDatasourceProvider).sendOtp(user.id);
            } catch (_) {
              if (!mounted) return;
              showCasaSnackbar(
                context,
                message: 'Não foi possível enviar o código 2FA.',
                isError: true,
              );
              return;
            }
            if (!mounted) return;
            ref.read(pendingOtpProvider.notifier).state = true;
            context.go(AppRoutes.otpVerification);
          } else {
            ref.read(pendingOtpProvider.notifier).state = false;
            context.go(AppRoutes.dashboard);
          }
        }
        if (user == null) {
          showCasaSnackbar(
            context,
            message: 'Login com Google cancelado.',
            isError: true,
          );
        }
      },
      error: (error, __) => showCasaSnackbar(
        context,
        message: mapAuthError(error, fallback: 'Falha ao entrar com Google.'),
        isError: true,
      ),
      loading: () {},
    );
  }

  Future<void> _resetPassword() async {
    if (_emailController.text.trim().isEmpty) {
      showCasaSnackbar(
        context,
        message: 'Informe o e-mail para recuperar a senha.',
        isError: true,
      );
      return;
    }

    try {
      await ref
          .read(authNotifierProvider.notifier)
          .sendPasswordReset(_emailController.text.trim());
      ref.read(analyticsServiceProvider).logPasswordReset();
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: 'Enviamos o link de redefinicao para seu e-mail.',
        isSuccess: true,
      );
    } catch (error, stackTrace) {
      ref.read(analyticsServiceProvider).recordHandledError(
            error,
            stackTrace,
            reason: 'auth_password_reset_failed',
          );
      if (!mounted) return;
      showCasaSnackbar(
        context,
        message: mapAuthError(
          error,
          fallback: 'Nao foi possivel enviar o e-mail de recuperacao.',
        ),
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return AuthShell(
      eyebrow: 'EducaStock',
      title: 'Bem-vinda de volta',
      subtitle: 'Acesse sua conta para continuar.',
      footerText: 'Ainda nao possui conta?',
      footerActionLabel: 'Criar cadastro',
      onFooterAction: () => context.go(AppRoutes.register),
      showBrandPanel: false,
      compactBrandPanel: true,
      showFeatureBadges: false,
      child: Stack(
        children: [
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Align(
                  alignment: Alignment.center,
                  child: AuthCenterLogo(
                    title: 'Entrar',
                    subtitle: 'Acesso rápido e seguro',
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Acesse com sua conta',
                  style: AppTypography.headingSmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                CasaTextField(
                  label: 'E-mail',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o e-mail';
                    if (!v.contains('@')) return 'E-mail invalido';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                CasaTextField(
                  label: 'Senha',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a senha';
                    if (v.length < 6) return 'Senha muito curta';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: isLoading
                              ? null
                              : () => setState(() => _rememberLogin = !_rememberLogin),
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _rememberLogin,
                                  onChanged: isLoading
                                      ? null
                                      : (value) =>
                                          setState(() => _rememberLogin = value ?? true),
                                ),
                                Text(
                                  'Manter login',
                                  style: AppTypography.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: isLoading ? null : _resetPassword,
                        child: const Text('Esqueci minha senha'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CasaButton(
                  label: 'Entrar',
                  onPressed: isLoading ? null : _submit,
                  isLoading: isLoading,
                  icon: Icons.login_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      child: Text(
                        'ou',
                        style: AppTypography.labelMedium.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                CasaButton(
                  label: 'Entrar com Google',
                  variant: CasaButtonVariant.secondary,
                  onPressed: isLoading ? null : _signInWithGoogle,
                  icon: Icons.g_mobiledata_rounded,
                ),
              ],
            ),
          ),
          if (isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withValues(alpha: 0.7),
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
