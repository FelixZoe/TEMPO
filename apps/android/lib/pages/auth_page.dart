import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/miui_theme.dart';
import '../services/auth_service.dart';
import '../services/cloud_sync_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'files_page.dart';

/// Auth flow: Email → check registered → Login / Register(with code)
class AuthPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const AuthPage({super.key, this.onLoginSuccess});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

enum _AuthStep { email, login, register, resetPassword }

class _AuthPageState extends State<AuthPage> with TickerProviderStateMixin {
  _AuthStep _step = _AuthStep.email;
  String _email = '';
  bool _loading = false;

  // Email step
  final _emailCtrl = TextEditingController();
  String? _emailError;

  // Login step
  final _loginPwCtrl = TextEditingController();
  bool _showLoginPw = false;

  // Reset password step
  final _resetCodeCtrl = TextEditingController();
  final _resetPwCtrl = TextEditingController();
  final _resetPw2Ctrl = TextEditingController();
  bool _showResetPw = false;
  bool _resetCodeSent = false;
  int _resetCountdown = 0;
  Timer? _resetCountdownTimer;

  // Register step
  final _regPwCtrl = TextEditingController();
  final _regPw2Ctrl = TextEditingController();
  final _regNickCtrl = TextEditingController();
  final _regCodeCtrl = TextEditingController();
  bool _showRegPw = false;
  bool _codeSent = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeInOut);
    _fadeCtrl.value = 1.0;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _resetCountdownTimer?.cancel();
    _fadeCtrl.dispose();
    _emailCtrl.dispose();
    _loginPwCtrl.dispose();
    _regPwCtrl.dispose();
    _regPw2Ctrl.dispose();
    _regNickCtrl.dispose();
    _regCodeCtrl.dispose();
    _resetCodeCtrl.dispose();
    _resetPwCtrl.dispose();
    _resetPw2Ctrl.dispose();
    super.dispose();
  }

  // ─── Email validation ───
  bool _isValidEmail(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  // ─── Step transition with animation ───
  Future<void> _goToStep(_AuthStep step) async {
    await _fadeCtrl.reverse();
    if (!mounted) return;
    setState(() => _step = step);
    _fadeCtrl.forward();
  }

  // ─── Step 1: Check email ───
  Future<void> _checkEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _emailError = '请输入邮箱地址');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _emailError = '邮箱格式不正确');
      return;
    }
    setState(() {
      _emailError = null;
      _loading = true;
    });

    final result = await AuthService().checkEmail(email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      _snack(result.error ?? '检查失败');
      return;
    }

    _email = email;
    if (result.registered) {
      // Existing user → login
      await _goToStep(_AuthStep.login);
    } else {
      // New user → register, auto-send verification code
      await _goToStep(_AuthStep.register);
      _autoSendCode();
    }
  }

  // ─── Auto send verification code on entering register/reset step ───
  Future<void> _autoSendCode() async {
    if (_codeSent || _countdown > 0) return;
    setState(() => _loading = true);
    final result = await AuthService().sendCode(_email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      _snack('验证码已自动发送到 $_email', isError: false);
      setState(() {
        _codeSent = true;
        _countdown = 60;
      });
      _startCountdown();
    } else {
      if (result.cooldown != null && result.cooldown! > 0) {
        setState(() {
          _countdown = result.cooldown!;
          _codeSent = true;
        });
        _startCountdown();
      }
      // Don't show error for auto-send; user can manually tap button
    }
  }

  Future<void> _autoSendResetCode() async {
    if (_resetCodeSent || _resetCountdown > 0) return;
    setState(() => _loading = true);
    final result = await AuthService().sendCode(_email);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      _snack('验证码已自动发送到 $_email', isError: false);
      setState(() {
        _resetCodeSent = true;
        _resetCountdown = 60;
      });
      _startResetCountdown();
    } else {
      if (result.cooldown != null && result.cooldown! > 0) {
        setState(() {
          _resetCountdown = result.cooldown!;
          _resetCodeSent = true;
        });
        _startResetCountdown();
      }
    }
  }

  // ─── Step 2a: Login ───
  Future<void> _doLogin() async {
    final pw = _loginPwCtrl.text;
    if (pw.isEmpty) {
      _snack('请输入密码');
      return;
    }
    setState(() => _loading = true);
    final result = await AuthService().login(email: _email, password: pw);
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      _snack('登录成功，正在同步云端数据...', isError: false);
      widget.onLoginSuccess?.call();
      // Clear stale caches from previous user
      FilesPage.clearCache();
      // Auto pull cloud data after login
      if (mounted) {
        final provider = context.read<AppProvider>();
        provider.pullAndReload().then((ok) {
          if (mounted) {
            _snack(ok ? '云端数据已同步' : '数据同步完成', isError: false);
          }
        });
      }
      Navigator.of(context).pop(true);
    } else {
      _snack(result.error ?? '登录失败');
    }
  }

  // ─── Step 2b: Send verification code ───
  Future<void> _sendCode() async {
    if (_countdown > 0) return;
    setState(() => _loading = true);
    final result = await AuthService().sendCode(_email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      _snack('验证码已发送到 $_email', isError: false);
      setState(() {
        _codeSent = true;
        _countdown = 60;
      });
      _startCountdown();
    } else {
      if (result.cooldown != null && result.cooldown! > 0) {
        setState(() {
          _countdown = result.cooldown!;
          _codeSent = true;
        });
        _startCountdown();
      }
      _snack(result.error ?? '发送失败');
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _countdown--;
        if (_countdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  // ─── Step 2b: Register ───
  Future<void> _doRegister() async {
    final pw = _regPwCtrl.text;
    final pw2 = _regPw2Ctrl.text;
    final nick = _regNickCtrl.text.trim();
    final code = _regCodeCtrl.text.trim();

    // Removed _codeSent gate: user may have received code already
    // (e.g. auto-send succeeded server-side but client state lost).
    // Let the server validate whether a code exists.
    if (code.isEmpty) {
      _snack('请输入验证码');
      // If code never sent, trigger send now
      if (!_codeSent) _autoSendCode();
      return;
    }
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _snack('验证码为6位数字');
      return;
    }
    if (pw.isEmpty) {
      _snack('请输入密码');
      return;
    }
    if (pw.length < 8) {
      _snack('密码至少8位');
      return;
    }
    // Password strength: require at least letter + digit
    if (!RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(pw)) {
      _snack('密码需包含字母和数字');
      return;
    }
    if (pw != pw2) {
      _snack('两次密码不一致');
      return;
    }
    // Sanitize nickname
    final safeNick = nick.replaceAll(RegExp(r'[<>"\\;]'), '').trim();

    setState(() => _loading = true);
    final result = await AuthService().register(
      email: _email,
      password: pw,
      nickname: safeNick.isNotEmpty ? safeNick : null,
      code: code,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      _snack('注册成功，正在同步数据...', isError: false);
      widget.onLoginSuccess?.call();
      // Clear stale caches
      FilesPage.clearCache();
      // New user: push local data to cloud
      CloudSyncService().pushToCloud();
      Navigator.of(context).pop(true);
    } else {
      _snack(result.error ?? '注册失败');
    }
  }

  void _snack(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? MiuiColors.red : MiuiColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Predictive-back: on email step, system back = pop page;
    // on other steps, system back = go to previous step (don't pop).
    return PopScope(
      canPop: _step == _AuthStep.email,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return; // Already popped (email step)
        // Navigate back within auth flow
        if (_step == _AuthStep.resetPassword) {
          _goToStep(_AuthStep.login);
        } else if (_step == _AuthStep.login || _step == _AuthStep.register) {
          _goToStep(_AuthStep.email);
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: _step == _AuthStep.email
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textPrimary),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: colors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () {
                    if (_step == _AuthStep.resetPassword) {
                      _goToStep(_AuthStep.login);
                    } else if (_step == _AuthStep.login ||
                        _step == _AuthStep.register) {
                      _goToStep(_AuthStep.email);
                    }
                  },
                ),
          systemOverlayStyle: isDark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Logo
                  Icon(Icons.bolt_rounded, size: 52, color: MiuiColors.blue),
                  const SizedBox(height: 12),
                  Text(
                    'TEMPO',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _step == _AuthStep.email
                        ? '输入邮箱开始'
                        : _step == _AuthStep.login
                        ? '欢迎回来'
                        : _step == _AuthStep.resetPassword
                        ? '重置密码'
                        : '创建新账号',
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
                  ),
                  const SizedBox(height: 36),

                  // Step content
                  if (_step == _AuthStep.email) _buildEmailStep(colors),
                  if (_step == _AuthStep.login) _buildLoginStep(colors),
                  if (_step == _AuthStep.register) _buildRegisterStep(colors),
                  if (_step == _AuthStep.resetPassword)
                    _buildResetPasswordStep(colors),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══ Step: Email ═══
  Widget _buildEmailStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _inputField(
          controller: _emailCtrl,
          hint: '邮箱地址',
          icon: Icons.email_outlined,
          colors: colors,
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          autofocus: true,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
          onSubmitted: (_) => _checkEmail(),
        ),
        const SizedBox(height: 8),
        Text(
          '我们会检查该邮箱是否已注册，自动进入登录或注册流程',
          style: TextStyle(fontSize: 12, color: colors.textTertiary),
        ),
        const SizedBox(height: 28),
        _actionButton('继续', _loading, _checkEmail, colors),
      ],
    );
  }

  // ═══ Step: Login ═══
  Widget _buildLoginStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show the email as a chip
        _emailChip(colors),
        const SizedBox(height: 20),
        _inputField(
          controller: _loginPwCtrl,
          hint: '输入密码',
          icon: Icons.lock_outline_rounded,
          colors: colors,
          obscure: !_showLoginPw,
          autofocus: true,
          suffix: IconButton(
            icon: Icon(
              _showLoginPw
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
            onPressed: () => setState(() => _showLoginPw = !_showLoginPw),
          ),
          onSubmitted: (_) => _doLogin(),
        ),
        const SizedBox(height: 28),
        _actionButton('登录', _loading, _doLogin, colors),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () {
              _resetCodeCtrl.clear();
              _resetPwCtrl.clear();
              _resetPw2Ctrl.clear();
              _resetCodeSent = false;
              _resetCountdown = 0;
              _goToStep(_AuthStep.resetPassword).then((_) {
                _autoSendResetCode();
              });
            },
            child: Text(
              '忘记密码？',
              style: TextStyle(
                fontSize: 14,
                color: MiuiColors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══ Step: Register ═══
  Widget _buildRegisterStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _emailChip(colors),
        const SizedBox(height: 20),

        // Verification code row
        Row(
          children: [
            Expanded(
              child: _inputField(
                controller: _regCodeCtrl,
                hint: '6位验证码',
                icon: Icons.verified_outlined,
                colors: colors,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_loading || _countdown > 0) ? null : _sendCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _countdown > 0
                      ? colors.surface
                      : MiuiColors.blue.withValues(alpha: 0.12),
                  foregroundColor: MiuiColors.blue,
                  disabledForegroundColor: colors.textTertiary,
                  disabledBackgroundColor: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  _countdown > 0
                      ? '${_countdown}s'
                      : (_codeSent ? '重新发送' : '发送验证码'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _inputField(
          controller: _regNickCtrl,
          hint: '昵称（可选）',
          icon: Icons.person_outline_rounded,
          colors: colors,
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _regPwCtrl,
          hint: '设置密码（至少8位，含字母和数字）',
          icon: Icons.lock_outline_rounded,
          colors: colors,
          obscure: !_showRegPw,
          suffix: IconButton(
            icon: Icon(
              _showRegPw
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
            onPressed: () => setState(() => _showRegPw = !_showRegPw),
          ),
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _regPw2Ctrl,
          hint: '确认密码',
          icon: Icons.lock_outline_rounded,
          colors: colors,
          obscure: true,
          onSubmitted: (_) => _doRegister(),
        ),
        const SizedBox(height: 28),
        _actionButton('注册', _loading, _doRegister, colors),
      ],
    );
  }

  // ═══ Step: Reset Password ═══
  Widget _buildResetPasswordStep(AppColors colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _emailChip(colors),
        const SizedBox(height: 8),
        Text(
          '验证码将发送到该邮箱，用于重置密码',
          style: TextStyle(fontSize: 12, color: colors.textTertiary),
        ),
        const SizedBox(height: 20),

        // Verification code row
        Row(
          children: [
            Expanded(
              child: _inputField(
                controller: _resetCodeCtrl,
                hint: '6位验证码',
                icon: Icons.verified_outlined,
                colors: colors,
                keyboardType: TextInputType.number,
                maxLength: 6,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: (_loading || _resetCountdown > 0)
                    ? null
                    : _sendResetCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _resetCountdown > 0
                      ? colors.surface
                      : MiuiColors.blue.withValues(alpha: 0.12),
                  foregroundColor: MiuiColors.blue,
                  disabledForegroundColor: colors.textTertiary,
                  disabledBackgroundColor: colors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(
                  _resetCountdown > 0
                      ? '${_resetCountdown}s'
                      : (_resetCodeSent ? '重新发送' : '发送验证码'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _resetPwCtrl,
          hint: '新密码（至少6位）',
          icon: Icons.lock_outline_rounded,
          colors: colors,
          obscure: !_showResetPw,
          suffix: IconButton(
            icon: Icon(
              _showResetPw
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              size: 20,
              color: colors.textTertiary,
            ),
            onPressed: () => setState(() => _showResetPw = !_showResetPw),
          ),
        ),
        const SizedBox(height: 14),
        _inputField(
          controller: _resetPw2Ctrl,
          hint: '确认新密码',
          icon: Icons.lock_outline_rounded,
          colors: colors,
          obscure: true,
          onSubmitted: (_) => _doResetPassword(),
        ),
        const SizedBox(height: 28),
        _actionButton('重置密码', _loading, _doResetPassword, colors),
      ],
    );
  }

  // ─── Send reset code (reuse send-code API) ───
  Future<void> _sendResetCode() async {
    if (_resetCountdown > 0) return;
    setState(() => _loading = true);
    final result = await AuthService().sendCode(_email);
    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      _snack('验证码已发送到 $_email', isError: false);
      setState(() {
        _resetCodeSent = true;
        _resetCountdown = 60;
      });
      _startResetCountdown();
    } else {
      if (result.cooldown != null && result.cooldown! > 0) {
        setState(() {
          _resetCountdown = result.cooldown!;
          _resetCodeSent = true;
        });
        _startResetCountdown();
      }
      _snack(result.error ?? '发送失败');
    }
  }

  void _startResetCountdown() {
    _resetCountdownTimer?.cancel();
    _resetCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resetCountdown--;
        if (_resetCountdown <= 0) timer.cancel();
      });
    });
  }

  // ─── Do reset password ───
  Future<void> _doResetPassword() async {
    final code = _resetCodeCtrl.text.trim();
    final pw = _resetPwCtrl.text;
    final pw2 = _resetPw2Ctrl.text;

    if (code.isEmpty) {
      _snack('请输入验证码');
      if (!_resetCodeSent) _autoSendResetCode();
      return;
    }
    if (code.length != 6 || !RegExp(r'^\d{6}$').hasMatch(code)) {
      _snack('验证码为6位数字');
      return;
    }
    if (pw.isEmpty) {
      _snack('请输入新密码');
      return;
    }
    if (pw.length < 8) {
      _snack('密码至少8位');
      return;
    }
    if (!RegExp(r'(?=.*[a-zA-Z])(?=.*\d)').hasMatch(pw)) {
      _snack('密码需包含字母和数字');
      return;
    }
    if (pw != pw2) {
      _snack('两次密码不一致');
      return;
    }

    setState(() => _loading = true);
    final result = await AuthService().resetPassword(
      email: _email,
      code: code,
      newPassword: pw,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (result.success) {
      _snack('密码已重置，请用新密码登录', isError: false);
      _loginPwCtrl.clear();
      _goToStep(_AuthStep.login);
    } else {
      _snack(result.error ?? '重置失败');
    }
  }

  // ─── Email chip (shown in login/register steps) ───
  Widget _emailChip(AppColors colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MiuiColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MiuiColors.blue.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.email_rounded, size: 18, color: MiuiColors.blue),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _email,
              style: TextStyle(
                fontSize: 14,
                color: MiuiColors.blue,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _goToStep(_AuthStep.email),
            child: Icon(
              Icons.edit_rounded,
              size: 16,
              color: MiuiColors.blue.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Shared input field ───
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required AppColors colors,
    bool obscure = false,
    TextInputType? keyboardType,
    Widget? suffix,
    ValueChanged<String>? onSubmitted,
    ValueChanged<String>? onChanged,
    String? errorText,
    bool autofocus = false,
    int? maxLength,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      autofocus: autofocus,
      maxLength: maxLength,
      inputFormatters: inputFormatters,
      style: TextStyle(fontSize: 16, color: colors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 15),
        prefixIcon: Icon(icon, color: colors.textSecondary, size: 22),
        suffixIcon: suffix,
        filled: true,
        fillColor: colors.surface,
        counterText: '',
        errorText: errorText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colors.divider.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MiuiColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MiuiColors.red, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: MiuiColors.red, width: 1.5),
        ),
      ),
    );
  }

  Widget _actionButton(
    String label,
    bool loading,
    VoidCallback onTap,
    AppColors colors,
  ) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: MiuiColors.blue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: MiuiColors.blue.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
