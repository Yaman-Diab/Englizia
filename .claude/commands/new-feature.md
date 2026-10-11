---
description: Scaffold a new feature (domain/data/presentation/injection + tests) following the project architecture
argument-hint: <feature_name> [short description]
---

Scaffold the feature `$ARGUMENTS` in this Flutter project.

Before writing code:
1. Read `CLAUDE.md`, `docs/ARCHITECTURE.md`, and §2–§5 of `docs/PLAYBOOK.md`.
2. Read the section of `docs/product/student-app-requirements.md` that describes this feature, and `docs/api/README.md`.
3. List the screens, entities, use cases and endpoints you plan, flag every backend field you would have to assume, and ask before continuing if the scope is unclear.

Then create, using `snake_case` file names and the feature name as the translation key prefix:

```
lib/features/<feature>/
├── <feature>_injection.dart            void register<Feature>Dependencies(GetIt sl)
├── domain/entities/                    final class X extends Equatable (no JSON)
├── domain/repositories/                abstract interface class XRepository → Future<Result<T>>
├── domain/usecases/                    XUseCase implements UseCase<T, XParams>
├── data/datasources/                   XRemoteDataSource + XRemoteDataSourceImpl (uses ApiClient only)
├── data/models/                        XModel.fromJson (JsonReader) / toJson / toEntity()
├── data/repositories/                  XRepositoryImpl — guard(() async => (await remote.x()).toEntity())
└── presentation/<screen>/{cubit,pages,widgets}/
test/features/<feature>/                model (fixture), datasource (FakeHttpAdapter), cubit (bloc_test), page (pumpLocalized at 375 + 320, ar + en)
test/fixtures/api/<endpoint>_<case>.json  sanitized responses (real if available, else marked ASSUMPTION)
```

Rules:
- Paths go in `core/network/api_endpoints.dart`; every unconfirmed field gets `// ASSUMPTION(api): ...` and a row in `docs/api/`.
- Register interfaces in DI; Cubits as factories. Add the one-line call in `lib/app/di.dart`.
- Add routes to `lib/app/router/app_routes.dart` and a policy in `route_policies.dart`.
- Strings in both `ar.json` and `en.json`; colors/text only via `context.colors` / `context.texts`.
- Finish with `dart format lib test`, `flutter analyze --fatal-infos`, `flutter test`, then propose commits (Conventional Commits, `CONTRIBUTING.md`). Do not push.
