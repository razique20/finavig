import 'package:in_app_review/in_app_review.dart';

import 'rating_prompt_service.dart';

/// Glue between [RatingPromptService] and the platform review sheet.
///
/// `InAppReview` opens the native in-app review dialog (App Store on iOS,
/// Play Store on Android) with no rate limit of its own — the cooldown /
/// max-asks policy in [RatingPromptPolicy] is what protects the user from
/// nagging. When the platform sheet is unavailable (sideloaded build, web,
/// tests), the capability probe reports false and the ask is skipped.
class RatingPromptUi {
  RatingPromptUi._();

  static final InAppReview _review = InAppReview.instance;

  /// Wire the production prompt into the service. Call once at startup.
  static void register() {
    RatingPromptService.instance.showPrompt = () async {
      if (await _review.isAvailable()) {
        await _review.requestReview();
      }
    };
    RatingPromptService.instance.canPromptOverride =
        () => _review.isAvailable();
  }
}
