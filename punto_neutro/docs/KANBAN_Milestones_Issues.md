## Kanban — Milestones y Issues (versión general)

Propósito
- Mantener un registro claro y general de hitos, issues y tarjetas Kanban para el proyecto Punto Neutro.
- Documento de referencia para planificación y asignación; no incluye ejemplos de implementación ni fragmentos de código.

Cómo usar este documento
- Cada hito (Milestone) agrupa un conjunto de issues de alto nivel.
- Cada issue describe el objetivo, criterios de aceptación y notas técnicas opcionales (sin código). El responsable crea la implementación según la arquitectura del equipo.
- Para crear una tarjeta Kanban: copiar el título del issue, añadir descripción corta, prioridad y estimación en puntos/h.

Reglas generales
- Mantener las descripciones concisas y orientadas a valor de negocio.
- No incluir ejemplos de implementación ni fragmentos SQL/HTTP/etc. en la descripción del issue; enlazar artefactos o tickets técnicos si es necesario.
- Indicar siempre criterios de aceptación claros y pasos de verificación.

Milestones

Milestone A — Fundamentos y estabilización
- Objetivo: Asegurar que la base del proyecto esté estable y que todo el equipo pueda reproducir el entorno de desarrollo.
- Issues clave (ejemplos de título):
  - Configurar entorno de desarrollo reproducible
  - Validar y ejecutar migraciones en entorno de pruebas
  - Establecer políticas RLS y pruebas de seguridad básica
  - Documentar contractos API y modelos de datos (esquema general)

Milestone B — Datos y analítica básica
- Objetivo: Garantizar que los datos necesarios para las vistas y los business questions estén disponibles y sean confiables.
- Issues clave:
  - Captura y persistencia de eventos relevantes (lecturas, interacciones)
  - Índices y optimizaciones para consultas analíticas
  - Definir y validar métricas clave para 5 Business Questions prioritarias
  - Pruebas de integridad y calidad de datos

Milestone C — Funcionalidades de usuario
- Objetivo: Entregar las features visibles por usuario (5 prioridades iniciales).
- Issues clave:
  - Autenticación y autorización (flujos principales)
  - Gestión de favoritos/bookmarks (upsert/toggle, sincronización)
  - Notificaciones (listado, marcar leídas)
  - Calificaciones y comentarios (crear/editar/visualizar)
  - Historial de lectura y vista de recomendaciones básicas

Milestone D — Experiencia offline y sincronización
- Objetivo: Que la app funcione de manera robusta en escenarios con conectividad intermitente.
- Issues clave:
  - Cola de sincronización y resolución de conflictos (política LWW o similar)
  - Retry/backoff y gestión de errores transitorios
  - Estrategia de caché (TTL, LRU) para datos críticos

Milestone E — Búsqueda y descubrimiento
- Objetivo: Implementar búsqueda eficiente y filtrado por categorías/fuentes.
- Issues clave:
  - Motor de búsqueda (requiere indexación y API de consulta)
  - Filtrado por categoría, fuente y fecha
  - Relevancia básica y pruebas de resultados

Milestone F — Observabilidad y QoS
- Objetivo: Instrumentar y medir salud y rendimiento.
- Issues clave:
  - Métricas de latencia y errores para endpoints críticos
  - Logging estructurado y trazabilidad de operaciones de sincronización
  - Dashboards para KPIs y Business Questions seleccionadas

Milestone G — Privacidad y cumplimiento
- Objetivo: Asegurar cumplimiento con políticas de privacidad y prácticas seguras.
- Issues clave:
  - Revisión de RLS y permisos por rol
  - Retención de datos y opciones de eliminación/portabilidad
  - Auditoría de accesos y cambios sensibles

Milestone H — Escalado y rendimiento
- Objetivo: Preparar el sistema para un mayor volumen de usuarios y datos.
- Issues clave:
  - Pruebas de carga para endpoints críticos
  - Estrategias de particionado/archivado para datos históricos
  - Plan de optimizaciones (índices, caches, batching)

Milestone I — Mantenimiento y deuda técnica
- Objetivo: Reducir deuda técnica y dejar una base limpia para futuras features.
- Issues clave:
  - Limpieza de código y eliminación de piezas no usadas
  - Actualizar documentación y contratos internos
  - Añadir tests básicos (unidad/integración) para flujos críticos

Plantilla sugerida para cada Issue (sin implementación)
- Título: Conciso y orientado a resultado
- Descripción: Qué se quiere lograr y por qué importa
- Criterios de aceptación: Lista numerada (mínimo 2)
- Dependencias: Otros issues o decisiones arquitectónicas
- Prioridad/estimación: Alta/Media/Baja y puntos o horas
- Responsable: Nombre o equipo

Definición de Done (por issue)
- Código entregado y revisado (si aplica)
- Pruebas automatizadas que cubran la funcionalidad esencial
- Documentación de uso y notas de despliegue
- Verificación manual de criterios de aceptación en entorno de pruebas

Gestión de tarjetas Kanban
- Columnas recomendadas: Backlog / To Do / In Progress / Blocked / Review / Done
- Separar tareas de investigación (spikes) de tareas de implementación

Siguientes pasos sugeridos
- Revisar esta versión general y acordar prioridad de milestones (reunión de planificación).
- Convertir cada issue prioritario en tarjetas del tablero Kanban y asignar responsables.
- Para tareas que requieran artefactos técnicos (migraciones, scripts), crear issues de soporte que enlacen los artefactos pero sin incrustarlos aquí.

Notas finales
- Este documento es intencionalmente general para permitir flexibilidad de implementación. Si desean, puedo generar una versión de issues lista para pegar en un gestor (GitHub Issues, Jira, etc.) sin incluir implementaciones.

--
Documento generado para planificación; mantener en el repositorio como fuente de verdad de alto nivel.
# Kanban: Milestones, Issues y tarjetas

Este archivo contiene TODAS las Milestones, Issues y tarjetas Kanban que debes poner en el tablero para completar el trabajo solicitado (orden y dependencias incluidos). Cópialo tal cual a tu herramienta de Kanban (GitHub Projects, Trello, Jira) y ajusta responsables/estimaciones según el equipo.

---

## Resumen de orden de trabajo (imperativo)
1. Do the Value Proposal on the Wiki (documentación pública).  
2. Implement the 5 Features (cada feature es una Milestone con Issues).  
3. Create the 5 Views (UI screens / wiring).  
4. Analyze the 5 Business Questions (BQ) in code / queries / endpoints.  
5. Micro-optimizations + use profiling tool (before/after).  
6. Re-run profiling and finalize.

> Nota: las Features y Views pueden desarrollarse en paralelo por sub-equipos, pero BQ y profiling dependen de que el modelo/FTS/columns y eventos estén implementados.

---

## Organización del tablero Kanban (recomendado)
- Columnas: Backlog → Ready → In Progress → PR/Review → QA → Done
- Swimlanes (opcional): Backend, Frontend, QA, Docs
- Labels: feature, view, bug, infra, db-migration, rls, spike, blocked, high-priority
- Definition of Done (DoD) para Issues: PR abierto, passing unit tests (si aplica), migrations aplicadas (si aplica), QA manual OK, documentación/base de datos actualizada.

---

## Milestone A — Wiki: Value Proposal
Goal: Publicar la propuesta de valor en la Wiki (página `Value-Proposition.md`).

Issues (put these as separate cards):
- A.1 Draft Value Proposition content (owner: UX/PO).  
  - Acceptance: Markdown listo, aprobado por PO.  
  - Estimate: 1sp
- A.2 Publish to repository Wiki or `docs/Value_Proposition.md` (owner: Dev).  
  - Acceptance: página visible en repo/wiki con link en README.  
  - Estimate: 0.5sp
- A.3 Add Mermaid diagram (optional) + link to architecture decisions (owner: Dev).  
  - Acceptance: Diagram embebido y renderable en GitHub Wiki.

Dependencies: Ninguna.

---

## Milestone B — Feature 1: Notification Bell (Eventual Connectivity)
Goal: Notificaciones locales + sincronización y API trigger para generar notificaciones desde engagement events.

Issues:
- B.1 DB: create `notifications` table + enum + RLS + trigger (SQL migration).  
  - Acceptance: Migration in `sql/` runs idempotently; triggers create notifications on `engagement_events`.
  - Label: db-migration, rls
  - Estimate: 3sp
- B.2 Backend: API endpoint to list/mark-as-read notifications (Paginated).  
  - Acceptance: endpoints `/notifications?limit=&offset=` and `PATCH /notifications/:id/read` work and respect RLS.
  - Label: infra, api
  - Estimate: 3sp
- B.3 Client: Local storage queue for pending notifications (persistence + UI integration).  
  - Acceptance: Notifications persisted locally when offline, shown in UI.
  - Label: frontend, offline
  - Estimate: 3sp
- B.4 Client: Sync Worker (Workmanager/Isolate) with exponential backoff.  
  - Acceptance: when network returns, worker syncs pending items and updates server; retries on fail.
  - Label: frontend, infra
  - Estimate: 4sp
- B.5 QA/Manual: test scenarios offline → post-reconnect.  
  - Acceptance: manual test sheet with cases and pass/fail.
  - Estimate: 1sp

Notes: The DB migration we added already; attach migration file to card `2025-11-15_add_user_preferences_and_notifications.sql`.

---

## Milestone C — Feature 2: Bookmarks (Local Storage + Eventual Connectivity)
Goal: Local-first bookmarks with sync queue and conflict resolution (LWW).

Issues:
- C.1 DB: enhance `bookmarks` with `updated_at`, `is_deleted`, unique index + RLS (migration).  
  - Acceptance: migration runs, constraints added.  
  - Label: db-migration, rls
  - Estimate: 2sp
- C.2 Client: Bookmark store (Hive/Room) — write-through local UI.  
  - Acceptance: user sees bookmarks instantly offline and changes are saved locally.
  - Label: frontend, offline
  - Estimate: 3sp
- C.3 Client: Sync queue + reconciliation policy (LWW) implementation.  
  - Acceptance: on reconnection, local changes are upserted/merged using `updated_at` timestamp.
  - Label: frontend, infra
  - Estimate: 4sp
- C.4 Backend: API to receive bookmark upserts & delete operations.  
  - Acceptance: idempotent upsert endpoint for bookmarks and proper handling of soft deletes.
  - Label: api
  - Estimate: 2sp
- C.5 QA: test concurrent updates conflict cases (2 devices).  
  - Acceptance: documented cases pass and LWW resolves predictably.
  - Estimate: 1sp

Dependencies: C.1 must be done before backend upserts; client sync depends on API availability.

---

## Milestone D — Feature 3: Reading History (Local-first)
Goal: Implement local-only reading history and optional server sync for analytics (table `news_read_history` created).

Issues:
- D.1 DB (optional): create `news_read_history` table + RLS (migration).  
  - Acceptance: migration present; optional (sync disabled by default).
  - Label: db-migration
  - Estimate: 1sp
- D.2 Client: Local history log (write-through): store `news_id`, `timestamp`, `duration`, `category`.  
  - Acceptance: Every open article creates a local history entry; history view reads local store.
  - Label: frontend, offline
  - Estimate: 3sp
- D.3 Client: History View (UI) and clear history action.  
  - Acceptance: view shows timeline, supports delete/clear.
  - Label: frontend
  - Estimate: 2sp
- D.4 (Optional) Backend: batch upload job for analytics (if enabled).  
  - Acceptance: endpoint to upload batches of history events.
  - Estimate: 2sp
- D.5 QA: offline-repeat + batch upload testing.  
  - Acceptance: test doc.
  - Estimate: 1sp

Notes: keep default app behavior 100% local; server sync opt-in.

---

## Milestone E — Feature 4: Create News (Multithreading + Local Storage + Eventual Connectivity)
Goal: Allow users to create news with image processing in background, draft autosave, and pending upload queue.

Issues:
- E.1 Client: Draft model + periodic autosave to local DB (Room/Hive) + resume.  
  - Acceptance: drafts autosave every Xs and can be resumed after app restart.
  - Label: frontend, offline
  - Estimate: 3sp
- E.2 Client: Image processing pipeline (compress + thumbnail) using Isolate/worker.  
  - Acceptance: image processed off main thread and UI remains responsive.
  - Label: frontend, performance
  - Estimate: 3sp
- E.3 Client: Pending Upload Queue + Background Uploader with exponential backoff.  
  - Acceptance: creates queue entries and background worker uploads when online.
  - Label: frontend, infra
  - Estimate: 4sp
- E.4 Backend: endpoints to accept article + image multipart (with idempotency keys).  
  - Acceptance: endpoint stores news_items and returns created id; supports idempotency.
  - Label: api, infra
  - Estimate: 3sp
- E.5 QA: test slow-network creation, retry/cancel, resume.  
  - Acceptance: passes manual tests.
  - Estimate: 2sp

Dependencies: E.4 backend must be present before uploads can be fully tested; E.2 and E.3 are client-side prioritized.

---

## Milestone F — Feature 5: Searcher + Search Cache (Caching + Eventual Connectivity)
Goal: Full-text search + client-side cache (Query → list of IDs, TTL, LRU).

Issues:
- F.1 DB: add `search_vector` tsvector generated column + GIN index and optional title lower index (migration).  
  - Acceptance: migration present and indexes created.
  - Label: db-migration
  - Estimate: 2sp
- F.2 Client: Search UI that queries local cache first, then server if miss.  
  - Acceptance: instant response on cached queries; consistent miss handling.
  - Label: frontend, offline
  - Estimate: 3sp
- F.3 Client: Cache module (LRU + TTL policy) with persistence.  
  - Acceptance: configurable TTL; eviction policy in place.
  - Label: frontend, infra
  - Estimate: 3sp
- F.4 Backend: search endpoint that uses FTS and returns list of IDs + highlights.  
  - Acceptance: `/search?q=&limit=` returns results and can accept `ids` only for cache mapping.
  - Label: api
  - Estimate: 3sp
- F.5 QA: cold start, offline, TTL expiry tests.  
  - Acceptance: documented and passing.
  - Estimate: 1sp

Notes: choose `spanish` config for to_tsvector if the content is mostly Spanish.

---

## Milestone G — Views (UI screens)
Goal: Implement five views and wire them to proper stores/APIs.

Views & Issues (a card per view + tasks):
- G.1 Preferences View
  - Tasks: UI layout, store (user_preferences API + local cache), favorites categories selector, night-mode toggle.  
  - Estimate: 3sp
- G.2 Notifications View
  - Tasks: list unread/read, pull-to-refresh, mark-all-read action, deep-link from bell icon.  
  - Estimate: 3sp
- G.3 Bookmarks & History View
  - Tasks: bookmarks list, history timeline, offline indicators, sync status badges.  
  - Estimate: 4sp
- G.4 Create News View
  - Tasks: editor, image picker, draft autosave indicator, upload status.  
  - Estimate: 4sp
- G.5 Search View
  - Tasks: search input, suggestions (cache-based), results list, offline message.  
  - Estimate: 3sp

Notes: Each view card should reference the feature cards that implement the backend and DB parts.

---

## Milestone H — 5 Business Questions (BQ) — Analysis & Code
Goal: Implement queries/endpoints to answer the five Business Questions (BQ) and include them in `sql/` + small endpoints or admin scripts.

BQ Issues (one card per question):
- H.1 BQ1: Can users make their experience more comfortable by customizing the app appearance? (Metric: % users with dark_mode enabled)
  - Tasks: DB query to count `user_preferences.dark_mode`, dashboard widget.
  - SQL Snippet: `select count(*) filter (where dark_mode) / nullif(count(*),0) as pct_dark from user_preferences;`
  - Estimate: 1sp
- H.2 BQ2: Can users contribute content to the community by submitting news or web content found online? (Metric: number of `news_items` created by users per week)
  - Tasks: weekly aggregation by `user_profile_id`; admin analytics endpoint.
  - Estimate: 1sp
- H.3 BQ3: Can the content shown on the home page be personalized for the user? (Metric: share of home impressions coming from users' favorite categories)
  - Tasks: log impressions with category and user, join `user_favorite_categories` to compute personalization ratio.
  - Estimate: 2sp
- H.4 BQ4: Are users aware of the actions they performed to evaluate their behavior in the app? (Metric: events per user — ratings, comments, reads)
  - Tasks: combine `engagement_events`, `rating_items`, `comments`, and optionally `news_read_history` to calculate actions per user and present UI.
  - Estimate: 2sp
- H.5 BQ5: Which source/platform (e.g., X, Instagram, Facebook) or newspaper do users feel least satisfied with, by category? (Metric: avg rating per `source_domain` + category)
  - Tasks: use `news_items.source_domain` + `rating_items` to compute average reliability/rating by domain and category; return lowest-ranked list.
  - Example SQL:
    ```sql
    select ni.source_domain,
           ni.category_id,
           avg(ri.assigned_reliability_score) as avg_rel,
           count(*) as cnt
    from public.news_items ni
    join public.rating_items ri on ri.news_item_id = ni.news_item_id
    group by ni.source_domain, ni.category_id
    order by ni.category_id, avg_rel asc
    limit 50;
    ```
  - Estimate: 3sp

Deliverables: SQL files in `sql/` and small dashboard endpoints or admin pages.

---

## Milestone I — Micro-optimizations + Profiling
Goal: Run profiler, implement quick wins (6 small optimizations), re-profile, and measure improvements.

Plan & Issues:
- I.1 Profiling baseline (frontend + backend).  
  - Tasks: run Flutter DevTools CPU/Memory, backend profiler (pg_stat_statements + CPU), collect traces.
  - Acceptance: baseline captured.
  - Estimate: 2sp
- I.2 Implement micro-optimizations (6 items). Examples:
  - a) Debounce search input, b) Use pagination for notifications, c) Optimize DB indexes for heavy queries, d) Use image lazy-loading/thumbnailing, e) Use efficient serialization (avoid large JSON), f) Cache expensive queries.
  - Acceptance: each optimization has a short PR and tests/benchmarks.
  - Estimate: 6 × 1sp = 6sp
- I.3 Re-run profiling and compare metrics (report).  
  - Acceptance: show before/after metrics and at least 10-30% improvement in targeted areas or documented rationale if not.
  - Estimate: 2sp

Notes: Add issues per micro-optimization and tag them `performance`.

---

## Cross-cutting & Infra issues (always present)
- X.1 Migrations CI: Add step to CI to apply SQL migrations to test DB.  
  - Estimate: 2sp
- X.2 RLS tests: end-to-end test that validates RLS policies per-user (smoke test).  
  - Estimate: 2sp
- X.3 Backups & Rollbacks: add reversible migrations or rollback scripts for DB changes.  
  - Estimate: 1sp
- X.4 Documentation: update README with feature flags and how to run local workers.  
  - Estimate: 1sp

---

## Suggested Kanban cards formatting (copy/paste template)
Title: [Feature] Notification Bell – Local queue + sync worker  
Labels: feature, frontend, backend, db-migration  
Assignee: @name  
Estimate: 4sp  
Description: Implement local pending-notifications queue, Workmanager worker and server endpoints. See `sql/2025-11-15_add_user_preferences_and_notifications.sql` for migration.  
Acceptance Criteria:  
- Local queue persists on app restart.  
- Worker syncs pending items when online and retries with exponential backoff.  
- Notifications appear in UI and can be marked read.

---

## PR checklist (copy into PR template)
- [ ] Described the problem & solution
- [ ] Linked Issues / Milestone
- [ ] Added/updated SQL migrations in `sql/` (idempotent)
- [ ] Added unit tests or manual test plan
- [ ] Updated docs (Wiki or README)
- [ ] QA checklist passed

---

## Tips para gestión del tablero
- Prioriza B-1 (notifications DB) y F-1 (search DB) early: DB changes unlock many features.  
- Group tasks by vertical feature teams: backend + frontend paired per feature reduces integration friction.  
- Use short 2-day cycles for features with automated QA after each PR.

---

## Archivos SQL mencionados (ya creados en repo)
- `sql/2025-11-15_add_user_preferences_and_notifications.sql` -> notifications + user_preferences
- `sql/2025-11-15_enhance_bookmarks_lww.sql` -> bookmarks enhancements
- `sql/2025-11-15_add_news_read_history.sql` -> optional read history
- `sql/2025-11-15_fulltext_search_news.sql` -> search_vector + indices
- `sql/2025-11-15_add_source_domain_generated_column.sql` -> source_domain
- `sql/2025-11-15_renumber_rating_items.sql` -> optional renumber script (use with care)

---

## How to use this file
- Create the Milestones in your project tool following the Milestone headings (A..I).  
- Under each Milestone create Issues using the Issues lists as Cards (copy Acceptance criteria & Estimates).  
- Use suggested Labels and link to the SQL files and PRs when relevant.

---

If quieres, genero automáticamente Issues en GitHub Projects con estos items (necesitaría permisos o un script). ¿Te preparo también la versión en inglés o un export CSV para importar al tablero?