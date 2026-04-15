// HTTP timeouts for long-running Pulse API operations (import, campaigns).
// Global NeyvoApi.setDefaultTimeout stays moderate; these apply per-call only.

/// POST /api/pulse/students/import/csv — large payload, parse, enqueue.
const Duration pulseImportCsvPost = Duration(minutes: 5);

/// GET /api/pulse/students/import/jobs/{id} — per poll; generous for slow Firestore.
const Duration pulseImportJobPoll = Duration(seconds: 90);

/// POST /api/pulse/campaigns/{id}/prepare — snapshot + validation.
const Duration pulseCampaignPrepare = Duration(minutes: 5);

/// POST /api/pulse/campaigns/{id}/rebuild-audience.
const Duration pulseCampaignRebuildAudience = Duration(minutes: 3);

/// POST /api/pulse/campaigns/{id}/start
const Duration pulseCampaignStart = Duration(seconds: 240);

/// POST /api/pulse/campaigns/{id}/retry
const Duration pulseCampaignRetry = Duration(seconds: 120);

/// Max wall-clock time for import job polling UI before we warn the user (pathological jobs).
const Duration pulseImportPollMaxWait = Duration(hours: 2);
