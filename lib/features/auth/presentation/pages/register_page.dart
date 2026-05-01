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

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberLogin = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
          rememberLogin: _rememberLogin,
        );

    final state = ref.read(authNotifierProvider);
    if (!mounted) return;
    state.when(
      data: (user) {
        if (user != null) {
          ref.read(analyticsServiceProvider).logAuthRegister();
          showCasaSnackbar(
            context,
            message: 'Conta criada com sucesso.',
            isSuccess: true,
          );
          context.go(AppRoutes.dashboard);
        }
        if (user == null) {
          showCasaSnackbar(
            context,
            message: 'Cadastro nao finalizado. Tente novamente.',
            isError: true,
          );
        }
      },
      error: (error, _) => showCasaSnackbar(
        context,
        message: mapAuthError(error, fallback: 'Nao foi possivel criar a conta.'),
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
      data: (user) {
        if (user != null) {
          ref.read(analyticsServiceProvider).logAuthLogin(method: 'google');
          context.go(AppRoutes.dashboard);
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;

    return AuthShell(
      eyebrow: 'EducaStock',
      title: 'Criar conta',
      subtitle: 'Configure seu acesso em poucos passos.',
      footerText: 'Ja possui conta?',
      footerActionLabel: 'Entrar',
      onFooterAction: () => context.go(AppRoutes.login),
      showBrandPanel: false,
      compactBrandPanel: true,
      showFeatureBadges: false,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.center,
              child: AuthCenterLogo(
                title: 'Criar conta',
                subtitle: 'Rápido e seguro',
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Crie seu acesso',
              style: AppTypography.headingSmall.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CasaTextField(
              label: 'Nome completo',
              controller: _nameController,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe seu nome';
                }
                if (value.trim().length < 3) {
                  return 'Nome muito curto';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'E-mail',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.email_outlined, size: 20),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Informe o e-mail';
                }
                if (!value.contains('@')) return 'E-mail invalido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'Senha',
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Informe a senha';
                if (value.length < 6) return 'Use pelo menos 6 caracteres';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            CasaTextField(
              label: 'Confirmar senha',
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              prefixIcon: const Icon(Icons.verified_user_outlined, size: 20),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Confirme a senha';
                }
                if (value != _passwordController.text) {
                  return 'As senhas nao conferem';
                }
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
            const SizedBox(height: AppSpacing.xl),
            CasaButton(
              label: 'Criar conta',
              onPressed: isLoading ? null : _submit,
              isLoading: isLoading,
              icon: Icons.person_add_alt_1_rounded,
            ),
            const SizedBox(height: AppSpacing.lg),
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
            const SizedBox(height: AppSpacing.lg),
            CasaButton(
              label: 'Continuar com Google',
              variant: CasaButtonVariant.secondary,
              onPressed: isLoading ? null : _signInWithGoogle,
              icon: Icons.g_mobiledata_rounded,
            ),
          ],
        ),
      ),
    );
  }
}