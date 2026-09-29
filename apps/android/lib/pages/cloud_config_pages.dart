import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../theme/miui_theme.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cloud_tools_service.dart';

// ═══ LinkSwift Configuration Page ═══
class LinkSwiftConfigPage extends StatefulWidget {
  final AppColors colors;
  const LinkSwiftConfigPage({super.key, required this.colors});
  @override
  State<LinkSwiftConfigPage> createState() => _LinkSwiftConfigPageState();
}

class _LinkSwiftConfigPageState extends State<LinkSwiftConfigPage> {
  bool _loading = false;
  String? _statusMessage;
  bool? _statusOk;

  final _yeUserCtrl = TextEditingController();
  final _yePassCtrl = TextEditingController();
  final _ucCookieCtrl = TextEditingController();
  final _qkCookieCtrl = TextEditingController();

  @override
  void dispose() {
    _yeUserCtrl.dispose();
    _yePassCtrl.dispose();
    _ucCookieCtrl.dispose();
    _qkCookieCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'LinkSwift 配置',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: MiuiColors.orange.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MiuiColors.orange.withValues(alpha: 0.15),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      size: 20,
                      color: MiuiColors.orange,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'LinkSwift 网盘直链配置',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '部分网盘平台需要配置账号信息才能解析直链。\n\n配置方式：\n1. 用户名密码登录：填写账号密码\n2. Cookie 方式：在浏览器登录后复制 Cookie',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _platformCard(
            colors,
            icon: Icons.cloud_outlined,
            name: '123盘',
            desc: '登录后可解析 123 盘直链',
            children: [
              _inputField('用户名/手机号', _yeUserCtrl, colors),
              const SizedBox(height: 10),
              _inputField('密码', _yePassCtrl, colors, obscure: true),
              const SizedBox(height: 12),
              _saveBtn(
                colors,
                () => _saveConfig('ye', '123盘', {
                  'username': _yeUserCtrl.text.trim(),
                  'password': _yePassCtrl.text.trim(),
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _platformCard(
            colors,
            icon: Icons.folder_outlined,
            name: 'UC网盘',
            desc: '浏览器登录后复制 Cookie',
            children: [
              _inputField('Cookie', _ucCookieCtrl, colors),
              const SizedBox(height: 12),
              _saveBtn(
                colors,
                () => _saveConfig('uc', 'UC网盘', {
                  'cookie': _ucCookieCtrl.text.trim(),
                }),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _platformCard(
            colors,
            icon: Icons.storage_outlined,
            name: '夸克网盘',
            desc: '浏览器登录后复制 Cookie',
            children: [
              _inputField('Cookie', _qkCookieCtrl, colors),
              const SizedBox(height: 12),
              _saveBtn(
                colors,
                () => _saveConfig('qk', '夸克网盘', {
                  'cookie': _qkCookieCtrl.text.trim(),
                }),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_statusOk == true ? MiuiColors.green : MiuiColors.red)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _statusOk == true
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: _statusOk == true
                        ? MiuiColors.green
                        : MiuiColors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _statusOk == true
                            ? MiuiColors.green
                            : MiuiColors.red,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MiuiColors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.tips_and_updates_rounded,
                      size: 18,
                      color: MiuiColors.blue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '如何获取 Cookie',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MiuiColors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '1. 在电脑浏览器中打开网盘官网并登录\n2. 按 F12 打开开发者工具\n3. 切换到 "网络(Network)" 标签\n4. 刷新页面，点击任意请求\n5. 在请求头(Headers)中找到 Cookie 字段\n6. 复制完整的 Cookie 值粘贴到上方',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.textSecondary,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _platformCard(
    AppColors colors, {
    required IconData icon,
    required String name,
    required String desc,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: MiuiColors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: MiuiColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _inputField(
    String hint,
    TextEditingController ctrl,
    AppColors colors, {
    bool obscure = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(fontSize: 13, color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.textTertiary, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  Widget _saveBtn(AppColors colors, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton(
        onPressed: _loading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: MiuiColors.orange,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                '保存配置',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }

  Future<void> _saveConfig(
    String key,
    String name,
    Map<String, String> config,
  ) async {
    final hasValue = config.values.any((v) => v.isNotEmpty);
    if (!hasValue) {
      setState(() {
        _statusMessage = '请填写 $name 的配置信息';
        _statusOk = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _statusMessage = '正在保存 $name 配置...';
      _statusOk = null;
    });
    try {
      final url = Uri.parse(
        '${ServerConfig.baseUrl}/api/cloud-tools/netdisk/config/$key',
      );
      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              ...ServerConfig.signedHeaders(
                '/api/cloud-tools/netdisk/config/$key',
              ),
              'X-User-Id': ServerConfig.userId,
            },
            body: json.encode(config),
          )
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _loading = false;
            _statusMessage = '$name 配置已保存';
            _statusOk = true;
          });
        } else {
          setState(() {
            _loading = false;
            _statusMessage =
                '$name 配置保存失败 (${response.statusCode})。该功能需要服务端支持，请联系管理员。';
            _statusOk = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = '网络错误，可直接在服务器配置文件中设置。';
          _statusOk = false;
        });
      }
    }
  }
}

// ═══ 去水印 Cookie 配置页 (多平台) ═══
class WatermarkCookieConfigPage extends StatefulWidget {
  final AppColors colors;
  const WatermarkCookieConfigPage({super.key, required this.colors});
  @override
  State<WatermarkCookieConfigPage> createState() =>
      _WatermarkCookieConfigPageState();
}

class _WatermarkCookieConfigPageState extends State<WatermarkCookieConfigPage> {
  final _douyinCtrl = TextEditingController();
  final _bilibiliCtrl = TextEditingController();
  final _kuaishouCtrl = TextEditingController();
  final _xiaohongshuCtrl = TextEditingController();
  bool _loading = false;
  String? _statusMessage;
  bool? _statusOk;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _isAdmin = AuthService().isAdmin;
  }

  @override
  void dispose() {
    _douyinCtrl.dispose();
    _bilibiliCtrl.dispose();
    _kuaishouCtrl.dispose();
    _xiaohongshuCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '云端工具配置',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // 管理员说明
          if (!_isAdmin)
            _infoCard(
              colors: colors,
              icon: Icons.admin_panel_settings_rounded,
              color: MiuiColors.orange,
              title: 'Cookie 配置（仅管理员）',
              desc: 'Cookie 配置影响所有用户，仅管理员账号可修改。\n如需配置请联系管理员。',
            ),
          if (_isAdmin)
            _infoCard(
              colors: colors,
              icon: Icons.auto_fix_high_rounded,
              color: MiuiColors.red,
              title: '去水印平台 Cookie 配置',
              desc: '配置各平台 Cookie 可提升解析成功率。\nCookie 过期后需重新配置。此配置对所有用户生效。',
            ),
          const SizedBox(height: 16),

          // 支持平台展示
          _supportedPlatformsCard(colors),
          const SizedBox(height: 16),

          if (_isAdmin) ...[
            // 抖音
            _cookiePlatformCard(
              colors: colors,
              icon: Icons.music_video_rounded,
              name: '抖音',
              platformKey: 'douyin',
              color: MiuiColors.red,
              ctrl: _douyinCtrl,
              hint: '从 douyin.com 登录后复制 Cookie...',
              apiPath: '/api/cloud-tools/watermark/api/hybrid/update_cookie',
              bodyBuilder: (cookie) => {'cookie': cookie, 'platform': 'douyin'},
            ),
            const SizedBox(height: 12),
            // B站
            _cookiePlatformCard(
              colors: colors,
              icon: Icons.videocam_rounded,
              name: 'B站 (Bilibili)',
              platformKey: 'bilibili',
              color: MiuiColors.blue,
              ctrl: _bilibiliCtrl,
              hint: '从 bilibili.com 登录后复制 Cookie...',
              apiPath: '/api/cloud-tools/watermark/api/hybrid/update_cookie',
              bodyBuilder: (cookie) => {
                'cookie': cookie,
                'platform': 'bilibili',
              },
            ),
            const SizedBox(height: 12),
            // 快手
            _cookiePlatformCard(
              colors: colors,
              icon: Icons.flash_on_rounded,
              name: '快手',
              platformKey: 'kuaishou',
              color: MiuiColors.orange,
              ctrl: _kuaishouCtrl,
              hint: '从 kuaishou.com 登录后复制 Cookie...',
              apiPath: '/api/cloud-tools/watermark/api/hybrid/update_cookie',
              bodyBuilder: (cookie) => {
                'cookie': cookie,
                'platform': 'kuaishou',
              },
            ),
            const SizedBox(height: 12),
            // 小红书
            _cookiePlatformCard(
              colors: colors,
              icon: Icons.favorite_rounded,
              name: '小红书',
              platformKey: 'xiaohongshu',
              color: MiuiColors.pink,
              ctrl: _xiaohongshuCtrl,
              hint: '从 xiaohongshu.com 登录后复制 Cookie...',
              apiPath: '/api/cloud-tools/watermark/api/hybrid/update_cookie',
              bodyBuilder: (cookie) => {'cookie': cookie, 'platform': 'xhs'},
            ),
          ],

          // 状态信息
          if (_statusMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (_statusOk == true ? MiuiColors.green : MiuiColors.red)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _statusOk == true
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 18,
                    color: _statusOk == true
                        ? MiuiColors.green
                        : MiuiColors.red,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 13,
                        color: _statusOk == true
                            ? MiuiColors.green
                            : MiuiColors.red,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Cookie 获取指南
          _cookieGuideCard(colors),
          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _infoCard({
    required AppColors colors,
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: TextStyle(
              fontSize: 13,
              color: colors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _supportedPlatformsCard(AppColors colors) {
    final platforms = [
      ('抖音', MiuiColors.red),
      ('快手', MiuiColors.orange),
      ('小红书', MiuiColors.pink),
      ('B站', MiuiColors.blue),
      ('微博', MiuiColors.red),
      ('TikTok', Colors.black),
      ('YouTube', MiuiColors.red),
      ('皮皮虾', MiuiColors.orange),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MiuiColors.green.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_outline_rounded,
                size: 18,
                color: MiuiColors.green,
              ),
              const SizedBox(width: 8),
              Text(
                '支持的平台',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MiuiColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: platforms
                .map(
                  (p) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: p.$2.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: p.$2.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      p.$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: p.$2 == Colors.black ? colors.textPrimary : p.$2,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            '大部分平台无需 Cookie 即可使用，仅部分平台需要配置',
            style: TextStyle(fontSize: 11, color: colors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _cookiePlatformCard({
    required AppColors colors,
    required IconData icon,
    required String name,
    required String platformKey,
    required Color color,
    required TextEditingController ctrl,
    required String hint,
    required String apiPath,
    required Map<String, String> Function(String) bodyBuilder,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Text(
                      '浏览器登录后复制 Cookie',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 90,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: ctrl,
              maxLines: null,
              style: TextStyle(
                fontSize: 11,
                color: colors.textPrimary,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration.collapsed(
                hintText: hint,
                hintStyle: TextStyle(color: colors.textTertiary, fontSize: 11),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // 粘贴按钮
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null && data!.text!.isNotEmpty) {
                      ctrl.text = data.text!;
                      if (mounted) setState(() {});
                    }
                  },
                  icon: const Icon(Icons.paste_rounded, size: 15),
                  label: const Text('粘贴', style: TextStyle(fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color.withValues(alpha: 0.3)),
                    minimumSize: const Size(0, 38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 清空
              OutlinedButton.icon(
                onPressed: () {
                  ctrl.clear();
                  if (mounted) setState(() {});
                },
                icon: const Icon(Icons.clear_rounded, size: 15),
                label: const Text('清空', style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.textSecondary,
                  side: BorderSide(color: colors.divider),
                  minimumSize: const Size(0, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 保存
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _saveCookie(
                          name,
                          ctrl.text.trim(),
                          apiPath,
                          bodyBuilder,
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 38),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '保存',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cookieGuideCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MiuiColors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.tips_and_updates_rounded,
                size: 18,
                color: MiuiColors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                '如何获取 Cookie',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MiuiColors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...[
                '1. 在电脑浏览器中打开平台官网并登录',
                '2. 按 F12 打开开发者工具',
                '3. 切换到 "Application" 或 "存储" 标签',
                '4. 在左侧 Cookies 中找到对应域名',
                '5. 复制所有 Cookie 值',
                '6. 粘贴到上方对应平台的输入框',
                '7. 点击保存',
              ]
              .map(
                (s) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '·',
                        style: TextStyle(
                          color: MiuiColors.blue,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MiuiColors.orange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: MiuiColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cookie 包含登录凭证，请勿分享给他人',
                    style: TextStyle(fontSize: 12, color: MiuiColors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCookie(
    String name,
    String cookie,
    String apiPath,
    Map<String, String> Function(String) bodyBuilder,
  ) async {
    if (cookie.isEmpty) {
      setState(() {
        _statusMessage = '请输入 $name 的 Cookie 内容';
        _statusOk = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _statusMessage = '正在保存 $name Cookie...';
      _statusOk = null;
    });
    try {
      final url = Uri.parse('${ServerConfig.baseUrl}$apiPath');
      final headers = {
        'Content-Type': 'application/json',
        ...ServerConfig.signedHeaders(apiPath),
        'X-User-Id': ServerConfig.userId,
      };
      final response = await http
          .post(url, headers: headers, body: json.encode(bodyBuilder(cookie)))
          .timeout(const Duration(seconds: 15));
      if (mounted) {
        if (response.statusCode == 200) {
          setState(() {
            _loading = false;
            _statusMessage = '$name Cookie 已保存成功！去水印功能已更新。';
            _statusOk = true;
          });
        } else {
          final errData = _tryDecodeJson(response.body);
          final errMsg =
              errData?['error'] ??
              errData?['message'] ??
              '保存失败 (${response.statusCode})';
          setState(() {
            _loading = false;
            _statusMessage = '$name Cookie 保存失败：$errMsg';
            _statusOk = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statusMessage = '网络错误，$name Cookie 未保存：$e';
          _statusOk = false;
        });
      }
    }
  }
}

// json decode helper
Map<String, dynamic>? _tryDecodeJson(String s) {
  try {
    return json.decode(s) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

// ═══════════════════════════════════════════════════════════════
//   Cloud Tools Reachability Page  (云端工具 · 测试通路)
// ═══════════════════════════════════════════════════════════════

class CloudReachabilityPage extends StatefulWidget {
  final AppColors colors;
  const CloudReachabilityPage({super.key, required this.colors});

  @override
  State<CloudReachabilityPage> createState() => _CloudReachabilityPageState();
}

class _CloudReachabilityPageState extends State<CloudReachabilityPage> {
  final CloudToolsService _service = CloudToolsService();
  final Map<String, CloudToolProbeResult> _results = {};
  final Set<String> _testing = {};
  bool _testingAll = false;
  DateTime? _lastRunAt;

  @override
  void initState() {
    super.initState();
    // Kick off an initial probe so the user sees status right away.
    WidgetsBinding.instance.addPostFrameCallback((_) => _probeAll());
  }

  Future<void> _probeOne(String toolId) async {
    if (_testing.contains(toolId)) return;
    HapticFeedback.selectionClick();
    setState(() => _testing.add(toolId));
    final result = await _service.probeTool(toolId);
    if (!mounted) return;
    setState(() {
      _testing.remove(toolId);
      _results[toolId] = result;
      _lastRunAt = DateTime.now();
    });
  }

  Future<void> _probeAll() async {
    if (_testingAll) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _testingAll = true;
      _testing.addAll(CloudToolsService.supportedProbes.map((p) => p.id));
    });
    final results = await _service.probeAll();
    if (!mounted) return;
    setState(() {
      for (final r in results) {
        _results[r.toolId] = r;
      }
      _testing.clear();
      _testingAll = false;
      _lastRunAt = DateTime.now();
    });
  }

  String _lastRunLabel() {
    if (_lastRunAt == null) return '';
    final diff = DateTime.now().difference(_lastRunAt!);
    if (diff.inSeconds < 5) return '刚刚';
    if (diff.inSeconds < 60) return '${diff.inSeconds}秒前';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    return '${diff.inHours}小时前';
  }

  int get _okCount => _results.values.where((r) => r.ok).length;
  int get _totalCount => CloudToolsService.supportedProbes.length;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final allDone = _results.length == _totalCount && _testing.isEmpty;
    final allOk = allDone && _okCount == _totalCount;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          '云端工具 · 测试通路',
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      body: RefreshIndicator(
        onRefresh: _probeAll,
        color: MiuiColors.blue,
        child: ListView(
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            _summaryCard(colors, allDone: allDone, allOk: allOk),
            const SizedBox(height: 18),
            ...CloudToolsService.supportedProbes.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _probeCard(colors, p),
              ),
            ),
            const SizedBox(height: 12),
            _tipCard(colors),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(
    AppColors colors, {
    required bool allDone,
    required bool allOk,
  }) {
    final Color accent = !allDone
        ? MiuiColors.blue
        : (allOk ? MiuiColors.green : MiuiColors.orange);
    final String title = !allDone
        ? (_testingAll ? '正在测试...' : '开始测试')
        : (allOk ? '全部通路正常' : '有 ${_totalCount - _okCount} 项异常');
    final String subtitle = _lastRunAt == null
        ? '点击下方按钮开始检测'
        : '上次检测 ${_lastRunLabel()} · $_okCount/$_totalCount 正常';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.10),
            accent.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              !allDone
                  ? Icons.network_check_rounded
                  : (allOk
                        ? Icons.check_circle_rounded
                        : Icons.warning_amber_rounded),
              color: accent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            height: 40,
            child: ElevatedButton(
              onPressed: _testingAll ? null : _probeAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                disabledBackgroundColor: accent.withValues(alpha: 0.55),
              ),
              child: _testingAll
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '全部测试',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _probeCard(AppColors colors, CloudToolProbe probe) {
    final result = _results[probe.id];
    final testing = _testing.contains(probe.id);

    Color statusColor;
    IconData statusIcon;
    String statusText;
    if (testing) {
      statusColor = MiuiColors.blue;
      statusIcon = Icons.sync_rounded;
      statusText = '检测中...';
    } else if (result == null) {
      statusColor = colors.textTertiary;
      statusIcon = Icons.help_outline_rounded;
      statusText = '未检测';
    } else if (result.ok) {
      statusColor = MiuiColors.green;
      statusIcon = Icons.check_circle_rounded;
      statusText = result.message;
    } else {
      statusColor = MiuiColors.red;
      statusIcon = Icons.error_outline_rounded;
      statusText = result.message;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: testing ? null : () => _probeOne(probe.id),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: statusColor.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: testing
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      )
                    : Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            probe.label,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (result != null && !testing && result.ok) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              result.latencyLabel,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result == null ? probe.description : statusText,
                      style: TextStyle(
                        fontSize: 12,
                        color: result == null
                            ? colors.textTertiary
                            : statusColor.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                testing ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                color: colors.textTertiary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tipCard(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: colors.textTertiary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '点击任意卡片单独重测。通路异常通常由服务临时不可用、网络问题、或配置过期（如 Cookie 失效）引起，可稍后再试或重新配置。',
              style: TextStyle(
                fontSize: 12,
                color: colors.textTertiary,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
