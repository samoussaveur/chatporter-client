# ChatPorter experimental workflow module

This branch adds a professional transport-request workflow to Twake Chat.
Normal Matrix messaging and existing navigation remain available.
The client communicates with a separate Rust/Axum/PostgreSQL service.

The location catalog contains only three invented demonstration entries.
No institution, real service, room, spatial catalog, patient, credential,
backup, runtime database or private document is included. Store private
deployment catalogs outside public repositories.

The request form, explicit transport requirements, assignment, instruction
waiting, resumption, closure, reopening and stable public references are
experimental. All authenticated users can read requests and their exchanges.
Only trusted service roles can manage the workflow; the server is authoritative.
Request data and exchanges in PostgreSQL do not inherit Matrix E2EE.

Configure CHATPORTER_API_URL when building. Backend setup is documented in
the separate chatporter-service repository. Upstream Flutter/build/codegen
requirements still apply. This is an alpha preview, not a production release.

## October 2026 additions

The messaging search bar includes a personnel section and opens an existing or new
private conversation. Authorized offline users are included. Enable the personal
contact fallback with --dart-define=CHATPORTER_CONTACTS_ENABLED=true when the
separate ChatPorter service is deployed; native ToM contacts remain the default.
Administrators have a permanent-deletion action with two confirmation dialogs;
authorization and concurrency checks remain on the server.

The published catalog is synthetic. The existing form tests retain their assertions
with demonstration identifiers/labels replacing the private deployment catalog.
Backend-only HL7 v2.6/FHIR R4 adapters are in the separate service repository; no
live clinical connection or patient prefill is available in this client.

## Reproducing the focused checks

```sh
flutter pub get --enforce-lockfile
flutter test --concurrency=1 --dart-define=CHATPORTER_CONTACTS_ENABLED=true test/modules/brancardage test/modules/directory test/modules/contacts
flutter analyze lib/modules/brancardage lib/modules/directory lib/data/network/contact/address_book_api.dart lib/domain/usecase/contacts/get_tom_contacts_interactor.dart lib/pages/search/search.dart lib/pages/search/search_view.dart test/modules/brancardage test/modules/directory test/modules/contacts
```

The contacts API integration fixture explicitly requires the compile-time fallback
flag. Omitting it fails that configuration assertion rather than silently skipping
the fallback test. These focused checks do not qualify the complete upstream suite
or a live institutional deployment.
