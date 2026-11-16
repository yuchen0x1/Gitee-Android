# Third-Party Research Notes

This file records open-source projects reviewed while improving Gitee Client. No third-party application implementation has been incorporated into Gitee Client. Research evidence and short excerpts are kept separately under `.evolution/`.

## GitTouch

- Source: https://github.com/pd4d10/git-touch
- License: Apache-2.0
- Reviewed ideas: one client surface for multiple Git hosting providers, release downloads, and provider capability boundaries.
- Use in this project: architectural reference only; no code copied.

## GitNex

- Source: https://github.com/gitnex-org/gitnex
- License: GPL-3.0
- Reviewed ideas: biometric lock, multiple accounts, repository/file workflows, and release visibility.
- Use in this project: product reference only; no code copied because the current project does not carry a compatible copyleft license.

## flutter-GitConnect

- Source: https://github.com/TheAlphamerc/flutter-GitConnect
- License: GPL-3.0
- Reviewed ideas: mobile repository navigation, inbox/activity surfaces, and settings organization.
- Use in this project: product reference only; no code copied.

## API Reference

- Gitee Releases API reference: https://gitee.com/sdk/gitee5j/blob/main/docs/RepositoriesApi.md
- GitHub REST Releases API reference: https://docs.github.com/en/rest/releases/releases

## DioHub

- Source: https://github.com/namanshergill/diohub
- License: GPL-3.0 (checked the source archive LICENSE).
- Reviewed: `lib/services/activity/notifications_service.dart`, `lib/view/notifications/widgets/filter_sheet.dart`, and notification cards on the `main` branch.
- Ideas used: explicit API filters, immutable read-state updates, and separation of notification models and UI.
- Use: product/architecture reference only; no implementation transplanted or new dependency introduced.

## FastHub

- Source: https://github.com/k0shk0sh/FastHub
- License: GPL-3.0 (checked the source archive LICENSE).
- Reviewed: `app/src/main/java/com/fastaccess/ui/modules/notification/` (`NotificationActivity`, `AllNotificationsFragment`, `AllNotificationsPresenter`) on `master`.
- Ideas used: unread/all inbox surfaces and explicit read actions. Gitee Client waits for the server response before changing state.
- Use: product reference only; no implementation transplanted.

## Source review on 2026-11-13

- GitTouch: `lib/screens/gh_notification.dart`, `lib/widgets/notification_item.dart`, `lib/models/notification.dart` (`main`), plus LICENSE.
- GitNex: `NotificationsFragment.java` and `NotificationsFragmentBottomSheet.java` under `app/src/main/java/org/mian/gitnex/` (`main`), plus LICENSE.
- GitConnect: `lib/bloc/notification/notification_bloc.dart` and `lib/resources/repository/notification_repository.dart` (`master`), plus LICENSE.
- Gitee contract: https://gitee.com/api/v5/doc_json (fetched from the endpoint used by the official documentation UI). Confirmed `unread`, the `{total_count, list}` envelope, PATCH single-read, and PUT all-read.
- Native biometric setup: https://pub.dev/packages/local_auth_android#activity-changes and the installed `local_auth_android 2.0.10` README/plugin source.
- Older clients remain useful design references; maintenance observations and evidence limits are recorded in `docs/EVOLUTION_2026-11-13.md`.
