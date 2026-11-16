import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/widgets/app_page.dart';
import '../../../../core/widgets/app_surfaces.dart';
import '../../../../core/widgets/food_image.dart';
import '../../controllers/capture_controller.dart';
import '../widgets/acq_capture_actions.dart';
import '../widgets/acq_method_card.dart';

/// 02 · Capture / choose a method (Scan/Add tab root).
class ScanAddScreen extends ConsumerWidget {
  const ScanAddScreen({super.key});

  Future<void> _takePhoto(BuildContext context, WidgetRef ref) async {
    if (!await acqConfirmFreshStart(context, ref)) return;
    if (context.mounted) context.push(acqCameraFreshRoute);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(captureControllerProvider).value;
    final hasOpen = acqDraftHasContent(draft);
    final n = draft?.detections.length ?? 0;

    return AppPage(
      title: 'What’s coming home?',
      subtitle: 'Add a little or a whole grocery haul.',
      showBack: false,
      children: [
        if (hasOpen)
          AcqMethodCard(
            icon: LucideIcons.listOrdered,
            title: 'Continue your review',
            subtitle: n == 0
                ? 'Photo selected · no items added yet · nothing saved'
                : '$n ${n == 1 ? 'item' : 'items'} waiting · nothing saved yet',
            onTap: () => context.push(Routes.review),
          ),
        const FoodImage(
          path: 'assets/images/groceries_counter_angled.jpg',
          height: 200,
          semanticLabel: 'Spinach, tomatoes and a bag of peas on a counter',
        ),
        Column(
          children: [
            AcqMethodCard(
              icon: LucideIcons.camera,
              title: 'Take a photo',
              subtitle: 'Containers, one item or market groceries',
              onTap: () => _takePhoto(context, ref),
            ),
            const SizedBox(height: 12),
            AcqMethodCard(
              icon: LucideIcons.imageUp,
              title: 'Upload a photo',
              subtitle: 'Choose from your gallery or files',
              onTap: () => acqStartUpload(context, ref),
            ),
            const SizedBox(height: 12),
            AcqMethodCard(
              icon: LucideIcons.scanBarcode,
              title: 'Scan barcode / QR',
              subtitle: 'Look up a packaged product',
              onTap: () => context.push(Routes.barcode),
            ),
            const SizedBox(height: 12),
            AcqMethodCard(
              icon: LucideIcons.pencilLine,
              title: 'Add manually',
              subtitle: 'You know it best. No scan needed.',
              onTap: () => context.push(Routes.manualAdd),
            ),
          ],
        ),
        const InfoCallout(
          title: 'You always get the final say',
          body:
              'Review and edit every item before it goes into your pantry. '
              'We’ll ask for camera or photo access only when you use it.',
        ),
      ],
    );
  }
}
