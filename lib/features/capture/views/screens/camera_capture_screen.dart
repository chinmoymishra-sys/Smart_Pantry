import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/enums/pantry_enums.dart';
import '../../../../core/navigation/routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_chip.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_states.dart';
import '../../controllers/capture_controller.dart';
import '../widgets/acq_capture_actions.dart';

/// 03 · Capture / camera.
///
/// Query parameters (optional): `mode=replace` swaps the photo of the open
/// draft and pops back; `confirmed=1` means the user already agreed to start
/// a fresh scan on the previous screen.
class CameraCaptureScreen extends ConsumerStatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  ConsumerState<CameraCaptureScreen> createState() =>
      _CameraCaptureScreenState();
}

enum _CamStatus { loading, ready, noCamera, failed }

class _CameraCaptureScreenState extends ConsumerState<CameraCaptureScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _cameras = const [];
  CameraController? _controller;
  CameraDescription? _current;
  _CamStatus _status = _CamStatus.loading;
  CaptureMode _mode = CaptureMode.groceries;
  bool _flashOn = false;
  bool _busy = false;
  bool _leaving = false;

  bool get _replaceMode =>
      GoRouterState.of(context).uri.queryParameters['mode'] == 'replace';
  bool get _confirmed =>
      GoRouterState.of(context).uri.queryParameters['confirmed'] == '1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final d = ref.read(captureControllerProvider).value;
    if (d != null) _mode = d.mode;
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final c = _controller;
    _controller = null;
    c?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (state == AppLifecycleState.inactive) {
      if (c == null || !c.value.isInitialized) return;
      setState(() {
        _controller = null;
        _status = _CamStatus.loading;
      });
      c.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (_controller == null && _current != null && !_leaving) {
        _initController(_current!);
      }
    }
  }

  Future<void> _setup() async {
    try {
      _cameras = await availableCameras();
    } catch (_) {
      _cameras = const [];
    }
    if (!mounted) return;
    if (_cameras.isEmpty) {
      setState(() => _status = _CamStatus.noCamera);
      return;
    }
    final back = _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
    await _initController(back);
  }

  Future<void> _initController(CameraDescription description) async {
    _current = description;
    final old = _controller;
    final controller = CameraController(
      description,
      ResolutionPreset.high,
      enableAudio: false,
    );
    setState(() {
      _controller = null;
      _status = _CamStatus.loading;
    });
    await old?.dispose();
    try {
      await controller.initialize();
      if (_flashOn) {
        await controller.setFlashMode(FlashMode.always);
      } else {
        await controller.setFlashMode(FlashMode.off);
      }
    } on CameraException catch (e) {
      await controller.dispose();
      if (!mounted) return;
      if (_isPermissionError(e.code)) {
        _goToPermission();
        return;
      }
      setState(() => _status = _CamStatus.failed);
      return;
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _status = _CamStatus.failed);
      return;
    }
    if (!mounted) {
      await controller.dispose();
      return;
    }
    setState(() {
      _controller = controller;
      _status = _CamStatus.ready;
    });
  }

  bool _isPermissionError(String code) =>
      code == 'CameraAccessDenied' ||
      code == 'CameraAccessDeniedWithoutPrompt' ||
      code == 'CameraAccessRestricted';

  void _goToPermission() {
    if (_leaving) return;
    _leaving = true;
    context.pushReplacement(Routes.permission('camera'));
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    final next = !_flashOn;
    try {
      await c.setFlashMode(next ? FlashMode.always : FlashMode.off);
      if (mounted) setState(() => _flashOn = next);
    } catch (_) {
      if (mounted) {
        showAppSnack(context, 'Flash isn’t available on this camera.');
      }
    }
  }

  Future<void> _flip() async {
    if (_cameras.length < 2 || _current == null || _busy) return;
    final i = _cameras.indexOf(_current!);
    await _initController(_cameras[(i + 1) % _cameras.length]);
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null ||
        !c.value.isInitialized ||
        c.value.isTakingPicture ||
        _busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      final shot = await c.takePicture();
      if (!mounted) return;
      await _usePhoto(shot.path, CaptureMethod.camera);
    } on CameraException catch (e) {
      if (!mounted) return;
      if (_isPermissionError(e.code)) {
        _goToPermission();
      } else {
        showAppSnack(context, 'The photo couldn’t be taken. Try again.');
      }
    } catch (e) {
      if (mounted) showAppSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    if (_busy) return;
    if (_replaceMode) {
      final path = await acqPickGalleryPhoto(context);
      if (path == null || !mounted) return;
      setState(() => _busy = true);
      try {
        await _usePhoto(path, CaptureMethod.upload);
      } catch (e) {
        if (mounted) showAppSnack(context, friendlyError(e));
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    } else {
      await acqStartUpload(
        context,
        ref,
        replace: true,
        skipConfirm: _confirmed,
      );
    }
  }

  Future<void> _usePhoto(String path, CaptureMethod method) async {
    final ctrl = ref.read(captureControllerProvider.notifier);
    if (_replaceMode && ctrl.draft != null) {
      await ctrl.replaceSourcePhoto(path);
      await ctrl.setMode(_mode);
      if (!mounted) return;
      _leaving = true;
      context.pop();
      return;
    }
    if (!_confirmed && !await acqConfirmFreshStart(context, ref)) return;
    await ctrl.start(method: method, mode: _mode, sourcePhotoPath: path);
    if (!mounted) return;
    _leaving = true;
    context.pushReplacement(Routes.selectedPhoto);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final children = <Widget>[
      ChoiceChips<CaptureMode>(
        options: CaptureMode.values,
        selected: _mode,
        labelOf: (m) => m.label,
        onSelected: (m) => setState(() => _mode = m),
      ),
    ];

    if (_status == _CamStatus.noCamera || _status == _CamStatus.failed) {
      final none = _status == _CamStatus.noCamera;
      children.add(
        StateCard(
          overline: none ? 'CAMERA · NOT AVAILABLE' : 'CAMERA · COULDN’T START',
          icon: LucideIcons.cameraOff,
          title: none ? 'No camera on this device' : 'The camera didn’t start',
          body: none
              ? 'Smart Pantry can’t find a camera it can use here. Upload a photo '
                    'or add food yourself. Nothing has been saved.'
              : 'Another app may be using it. Try again, upload a photo or add '
                    'food yourself. Nothing has been saved.',
          actions: [
            if (!none)
              AppButton(
                label: 'Try again',
                icon: LucideIcons.refreshCw,
                onPressed: () {
                  setState(() => _status = _CamStatus.loading);
                  _setup();
                },
              ),
            if (none)
              AppButton(
                label: 'Upload a photo',
                icon: LucideIcons.imageUp,
                onPressed: _gallery,
              )
            else
              AppButton.secondary(
                label: 'Upload a photo',
                icon: LucideIcons.imageUp,
                onPressed: _gallery,
              ),
            AppButton.secondary(
              label: 'Add manually',
              onPressed: () => context.pushReplacement(Routes.manualAdd),
            ),
          ],
        ),
      );
    } else {
      children
        ..add(_viewfinder(c))
        ..add(
          Text(
            'Keep foods separate and labels visible. For a container, '
            'photograph the food and its label.',
            textAlign: TextAlign.center,
            style: AppTypography.subtitle.copyWith(color: c.textMuted),
          ),
        )
        ..add(_controls(c))
        ..add(
          AppButton.secondary(
            label: 'Add manually instead',
            onPressed: () => context.push(Routes.manualAdd),
          ),
        );
    }

    return AppPage(
      title: 'Let’s see what you have',
      subtitle: 'Food photo · Nothing is saved yet',
      children: children,
    );
  }

  Widget _viewfinder(AppColors c) {
    final ctrl = _controller;
    Widget preview;
    if (ctrl != null && ctrl.value.isInitialized) {
      final size = ctrl.value.previewSize;
      preview = size == null
          ? CameraPreview(ctrl)
          : FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              // previewSize is reported in landscape orientation.
              child: SizedBox(
                width: size.height,
                height: size.width,
                child: CameraPreview(ctrl),
              ),
            );
    } else {
      preview = Center(
        child: SizedBox.square(
          dimension: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      );
    }
    return Semantics(
      label: 'Camera viewfinder',
      child: SizedBox(
        height: 352,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.viewfinder),
          child: ColoredBox(
            color: c.cameraSurface,
            child: Stack(
              fit: StackFit.expand,
              children: [
                preview,
                Positioned(
                  left: 24,
                  top: 24,
                  right: 24,
                  bottom: 48,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 2),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                    ),
                  ),
                ),
                Positioned(left: 16, top: 16, child: _flashPill()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // The pill sits on the live preview, so it keeps the design's light
  // treatment in both themes.
  Widget _flashPill() {
    const ink = Color(0xFF111827);
    return Semantics(
      button: true,
      toggled: _flashOn,
      label: _flashOn ? 'Flash on' : 'Flash off',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _controller == null ? null : _toggleFlash,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _flashOn ? LucideIcons.zap : LucideIcons.zapOff,
                  size: 18,
                  color: ink,
                ),
                const SizedBox(width: 6),
                Text(
                  _flashOn ? 'Flash on' : 'Flash off',
                  style: AppTypography.caption.copyWith(color: ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controls(AppColors c) {
    final canShoot = _controller != null && !_busy;
    final canFlip = _cameras.length > 1 && !_busy && _controller != null;
    return Row(
      children: [
        _sideControl(
          c,
          icon: LucideIcons.images,
          label: 'Gallery',
          onTap: _busy ? null : _gallery,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: SizedBox(
            height: 76,
            child: Center(
              child: Semantics(
                button: true,
                enabled: canShoot,
                label: 'Take photo',
                excludeSemantics: true,
                child: Material(
                  color: canShoot ? c.primary : c.surfaceMuted,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: canShoot ? c.primary : c.surfaceMuted,
                      width: 6,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: canShoot ? _capture : null,
                    child: SizedBox.square(
                      dimension: 72,
                      child: Center(
                        child: _busy
                            ? SizedBox.square(
                                dimension: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: c.onPrimary,
                                ),
                              )
                            : Icon(
                                LucideIcons.camera,
                                size: 28,
                                color: canShoot ? c.onPrimary : c.textMuted,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        _sideControl(
          c,
          icon: LucideIcons.switchCamera,
          label: 'Flip',
          onTap: canFlip ? _flip : null,
        ),
      ],
    );
  }

  Widget _sideControl(
    AppColors c, {
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
  }) {
    final color = onTap == null ? c.textMuted : c.textPrimary;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.buttonRadius,
        child: SizedBox(
          width: 80,
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 26, color: color),
              const SizedBox(height: 8),
              Text(label, style: AppTypography.caption.copyWith(color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
