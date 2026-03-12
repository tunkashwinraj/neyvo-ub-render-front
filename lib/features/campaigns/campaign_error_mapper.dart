// lib/features/campaigns/campaign_error_mapper.dart
// Maps backend campaign error codes to user-facing messages and suggested actions.

/// User-facing message and optional suggested action for a campaign error code.
class CampaignErrorInfo {
  const CampaignErrorInfo({
    required this.message,
    this.suggestedAction,
  });

  final String message;
  final String? suggestedAction;
}

/// Known campaign error codes from the backend.
const Set<String> knownCampaignErrorCodes = {
  'AUDIENCE_LOCKED',
  'SNAPSHOT_NOT_READY',
  'VALIDATION_FAILED',
  'INVALID_PHONES',
  'INSUFFICIENT_CREDITS',
};

/// Returns user-facing message and suggested action for a campaign error code.
CampaignErrorInfo campaignErrorInfo(String? code) {
  switch (code) {
    case 'AUDIENCE_LOCKED':
      return const CampaignErrorInfo(
        message: 'Audience is locked for this campaign.',
        suggestedAction: 'Use Rebuild Audience to change it or create a new campaign.',
      );
    case 'SNAPSHOT_NOT_READY':
      return const CampaignErrorInfo(
        message: 'Audience snapshot is not ready.',
        suggestedAction: 'Go to Preview & Prepare and run "Lock Audience & Run Validation".',
      );
    case 'VALIDATION_FAILED':
      return const CampaignErrorInfo(
        message: 'Validation failed.',
        suggestedAction: 'Fix the issues shown in Preview & Prepare and run validation again.',
      );
    case 'INVALID_PHONES':
      return const CampaignErrorInfo(
        message: 'Some phone numbers in the audience are invalid.',
        suggestedAction: 'Check contacts and remove or correct invalid numbers.',
      );
    case 'INSUFFICIENT_CREDITS':
      return const CampaignErrorInfo(
        message: 'Not enough credits to run this campaign.',
        suggestedAction: 'Add credits in Billing to place calls.',
      );
    default:
      return CampaignErrorInfo(
        message: code != null && code.isNotEmpty ? 'Campaign error: $code' : 'Something went wrong.',
        suggestedAction: null,
      );
  }
}
