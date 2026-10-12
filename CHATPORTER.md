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
