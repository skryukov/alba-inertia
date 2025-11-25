# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog],
and this project adheres to [Semantic Versioning].

## [Unreleased]

### Added

- Support for `InertiaRails.scroll` attributes. ([@skryukov])

## [0.1.1] - 2025-11-05

### Added

- Add `on_missing_serializer` configuration option to control behavior when serializer/resource classes are not found. ([@skryukov])
  Options: `:ignore` (default), `:log`, `:raise`, or a custom callable (proc/lambda)

### Fixed

- Namespaced controller serializers discovery (`Foo::BarController#baz` => `Foo::BarBazResource`/`Foo::BarBazSerializer`). ([@skryukov])

## [0.1.0] - 2025-11-04

### Added

- Initial release ([@skryukov])

[@skryukov]: https://github.com/skryukov

[Unreleased]: https://github.com/skryukov/alba-inertia/compare/v0.1.0...HEAD
[0.1.1]: https://github.com/skryukov/alba-inertia/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/skryukov/alba-inertia/commits/v0.1.0

[Keep a Changelog]: https://keepachangelog.com/en/1.0.0/
[Semantic Versioning]: https://semver.org/spec/v2.0.0.html
