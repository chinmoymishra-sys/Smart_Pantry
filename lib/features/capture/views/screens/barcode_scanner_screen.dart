import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_fields.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';

/// 07 · Alternative capture / barcode.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  MobileScannerController _scanner = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  int _scannerGeneration = 0;
  final _codeCtrl = TextEditingController();
  bool _handling = false;
  bool _permissionDenied = false;
  bool _codeError = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanner.addListener(_onScannerState);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanner.removeListener(_onScannerState);
    unawaited(_scanner.dispose());
    _codeCtrl.dispose();
    super.dispose();
  }

  bool get _isCurrentRoute => ModalRoute.of(context)?.isCurrent ?? false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        if (!_permissionDenied) unawaited(_safe(_scanner.stop));
      case AppLifecycleState.resumed:
        if (_permissionDenied) {
          // The user may have allowed access in Settings: try again.
          _recreateScanner();
        } else if (!_handling && _isCurrentRoute) {
          unawaited(_safe(_scanner.start));
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        break;
    }
  }

  Future<void> _safe(Future<void> Function() f) async {
    try {
      await f();
    } catch (_) {
      // Start/stop races (e.g. already stopped) are harmless here.
    }
  }

  void _onScannerState() {
    final err = _scanner.value.error;
    if (err?.errorCode == MobileScannerErrorCode.permissionDenied &&
        !_permissionDenied &&
        mounted) {
      setState(() => _permissionDenied = true);
    }
  }

  void _recreateScanner() {
    final old = _scanner;
    old.removeListener(_onScannerState);
    setState(() {
      _scanner = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      )..addListener(_onScannerState);
      _scannerGeneration++;
      _permissionDenied = false;
    });
    unawaited(old.dispose());
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    String? code;
    for (final b in capture.barcodes) {
      final v = b.rawValue?.trim();
      if (v != null && v.isNotEmpty) {
        code = v;
        break;
      }
    }
    if (code == null) return;
    _handling = true;
    await _safe(_scanner.stop);
    if (!mounted) return;
    HapticFeedback.selectionClick();
    await context.push(Routes.barcodeResult(code));
    if (!mounted) return;
    _handling = false;
    // Resume only when the user came back here ("Try scanning again").
    if (_isCurrentRoute && !_permissionDenied) {
      unawaited(_safe(_scanner.start));
    }
  }

  Future<void> _toggleTorch() async {
    if (_scanner.value.torchState == TorchState.unavailable) {
      showAppSnack(context, 'Flash isn’t available on this camera.');
      return;
    }
    await _safe(_scanner.toggleTorch);
  }

  Future<void> _lookUp() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = true);
      showAppSnack(context, 'Enter the barcode number shown on the package.');
      return;
    }
    setState(() => _codeError = false);
    FocusScope.of(context).unfocus();
    _handling = true;
    await _safe(_scanner.stop);
    if (!mounted) return;
    await context.push(Routes.barcodeResult(code));
    if (!mounted) return;
    _handling = false;
    if (_isCurrentRoute && !_permissionDenied) {
      unawaited(_safe(_scanner.start));
    }
  }

  Future<void> _openSettings() async {
    var ok = false;
    try {
      ok = await openAppSettings();
    } catch (_) {}
    if (!ok && mounted) {
      showAppSnack(
        context,
        'Couldn’t open Settings. Allow camera access for Smart Pantry in your device Settings.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppPage(
      title: 'Scan a barcode or QR',
      subtitle: 'For packaged food with a product code.',
      children: [
        if (_permissionDenied)
          StateCard(
            overline: 'CAMERA · PERMISSION DENIED',
            icon: LucideIcons.cameraOff,
            title: 'Camera access is off',
            body:
                'Smart Pantry needs camera access to scan a barcode. Enable '
                'it in Settings, or type the code below.',
            actions: [
              AppButton(
                label: 'Open device Settings',
                onPressed: _openSettings,
              ),
            ],
          )
        else ...[
          _scannerBox(c),
          Text(
            'Keep the package steady and avoid glare. We’ll look for a '
            'matching product record.',
            textAlign: TextAlign.center,
            style: AppTypography.subtitle.copyWith(color: c.textMuted),
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _scanner,
            builder: (context, state, _) {
              final on = state.torchState == TorchState.on;
              return AppButton.secondary(
                label: on ? 'Flash on' : 'Flash off',
                icon: on ? LucideIcons.zap : LucideIcons.zapOff,
                onPressed: _toggleTorch,
              );
            },
          ),
        ],
        LabeledField(
          label: 'Or enter the code',
          child: AppTextField(
            controller: _codeCtrl,
            hint: 'Type barcode number',
            semanticLabel: 'Barcode number',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            error: _codeError,
            onChanged: (_) {
              if (_codeError) setState(() => _codeError = false);
            },
            onSubmitted: (_) => _lookUp(),
          ),
        ),
        Column(
          children: [
            AppButton(label: 'Look up code', onPressed: _lookUp),
            const SizedBox(height: AppSpacing.xl),
            AppButton.secondary(
              label: 'No code? Take a food photo',
              onPressed: () => context.pushReplacement(Routes.camera),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scannerBox(AppColors c) {
    // Overlay sits on the dark viewfinder, so it stays white in both themes.
    return SizedBox(
      height: 300,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadii.viewfinder),
        child: ColoredBox(
          color: c.cameraSurface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                key: ValueKey(_scannerGeneration),
                controller: _scanner,
                onDetect: _onDetect,
                useAppLifecycleState: false,
                placeholderBuilder: (_) => ColoredBox(color: c.cameraSurface),
                errorBuilder: (context, error) => _ScannerMessage(
                  text: error.errorCode == MobileScannerErrorCode.unsupported
                      ? 'Scanning isn’t available on this device. Type the code below.'
                      : 'The scanner couldn’t start. Type the code below.',
                  background: c.cameraSurface,
                ),
              ),
              IgnorePointer(
                child: Stack(
                  children: [
                    Positioned(
                      left: 38,
                      right: 38,
                      top: 70,
                      height: 148,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 2),
                          borderRadius: BorderRadius.circular(AppRadii.button),
                        ),
                        child: const Center(
                          child: Icon(
                            LucideIcons.scanBarcode,
                            size: 80,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 40,
                      child: Text(
                        'Place the whole code inside the frame',
                        textAlign: TextAlign.center,
                        style: AppTypography.subtitle.copyWith(
                          color: Colors.white,
                        ),
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

class _ScannerMessage extends StatelessWidget {
  const _ScannerMessage({required this.text, required this.background});
  final String text;
  final Color background;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: background,
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(color: Colors.white70),
        ),
      ),
    ),
  );
}
