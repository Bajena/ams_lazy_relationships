# Change Log

## [v0.1.5](https://github.com/Bajena/ams_lazy_relationships/tree/v0.1.5) (2020-01-08)
[Full Changelog](https://github.com/Bajena/ams_lazy_relationships/compare/v0.1.4...v0.1.5)

**Closed issues:**

- Extract a base class for the loaders [\#39](https://github.com/Bajena/ams_lazy_relationships/issues/39)
- "Association" loader loads unnecessary records on AR 5.2.3+ [\#37](https://github.com/Bajena/ams_lazy_relationships/issues/37)
- undefined method `load\_all\_lazy\_relationships' for nil:NilClass [\#30](https://github.com/Bajena/ams_lazy_relationships/issues/30)
- Convert loaders to use strings instead of records as main keys [\#24](https://github.com/Bajena/ams_lazy_relationships/issues/24)

**Merged pull requests:**

- Improve tests for nested serializer lookup [\#43](https://github.com/Bajena/ams_lazy_relationships/pull/43) ([stokarenko](https://github.com/stokarenko))
- Extract a base class for lazy loaders [\#40](https://github.com/Bajena/ams_lazy_relationships/pull/40) ([Bajena](https://github.com/Bajena))
- Filter out preloaded records in `Association` preloader [\#36](https://github.com/Bajena/ams_lazy_relationships/pull/36) ([Bajena](https://github.com/Bajena))
- Synchronize lazy relationships [\#35](https://github.com/Bajena/ams_lazy_relationships/pull/35) ([stokarenko](https://github.com/stokarenko))
- Fix nested serializer lookup [\#34](https://github.com/Bajena/ams_lazy_relationships/pull/34) ([stokarenko](https://github.com/stokarenko))
- Fix batch loader dependency [\#33](https://github.com/Bajena/ams_lazy_relationships/pull/33) ([stokarenko](https://github.com/stokarenko))
- Bump rack from 2.0.6 to 2.0.8 [\#32](https://github.com/Bajena/ams_lazy_relationships/pull/32) ([dependabot[bot]](https://github.com/apps/dependabot))
- Bump loofah from 2.2.3 to 2.3.1 [\#31](https://github.com/Bajena/ams_lazy_relationships/pull/31) ([dependabot[bot]](https://github.com/apps/dependabot))

## [v0.1.4](https://github.com/Bajena/ams_lazy_relationships/tree/v0.1.4) (2019-06-02)
[Full Changelog](https://github.com/Bajena/ams_lazy_relationships/compare/v0.1.3...v0.1.4)

**Closed issues:**

- Use replace\_methods: false by default in loaders [\#28](https://github.com/Bajena/ams_lazy_relationships/issues/28)
- Require less restrictive batch-loader version [\#25](https://github.com/Bajena/ams_lazy_relationships/issues/25)
- Profile time and memory usage [\#21](https://github.com/Bajena/ams_lazy_relationships/issues/21)
- Loading circular relationships [\#20](https://github.com/Bajena/ams_lazy_relationships/issues/20)
- Add railtie [\#19](https://github.com/Bajena/ams_lazy_relationships/issues/19)

**Merged pull requests:**

- Use replace\_methods: false in batch loaders [\#29](https://github.com/Bajena/ams_lazy_relationships/pull/29) ([Bajena](https://github.com/Bajena))
- Add benchmark for speed & memory usage [\#27](https://github.com/Bajena/ams_lazy_relationships/pull/27) ([Bajena](https://github.com/Bajena))
- Require less restrictive batch loader version [\#26](https://github.com/Bajena/ams_lazy_relationships/pull/26) ([Bajena](https://github.com/Bajena))

## [v0.1.3](https://github.com/Bajena/ams_lazy_relationships/tree/v0.1.3) (2019-05-19)
[Full Changelog](https://github.com/Bajena/ams_lazy_relationships/compare/0.1.2...v0.1.3)

**Closed issues:**

- Association loader shouldn't yield cached associations data instantly  [\#22](https://github.com/Bajena/ams_lazy_relationships/issues/22)
- Customize loading behavior [\#14](https://github.com/Bajena/ams_lazy_relationships/issues/14)

**Merged pull requests:**

- Do not yield cached associations data instantly in Association loader [\#23](https://github.com/Bajena/ams_lazy_relationships/pull/23) ([Bajena](https://github.com/Bajena))

## [0.1.2](https://github.com/Bajena/ams_lazy_relationships/tree/0.1.2) (2019-03-10)
[Full Changelog](https://github.com/Bajena/ams_lazy_relationships/compare/v0.1.1...0.1.2)

**Closed issues:**

- Broken sqlite dependency [\#16](https://github.com/Bajena/ams_lazy_relationships/issues/16)

**Merged pull requests:**

- Add tests for lazy relationships inheritance [\#18](https://github.com/Bajena/ams_lazy_relationships/pull/18) ([Bajena](https://github.com/Bajena))
- Lock sqlite dependency [\#17](https://github.com/Bajena/ams_lazy_relationships/pull/17) ([Bajena](https://github.com/Bajena))
- Fix superclass lazy relationships not loading properly on subclass [\#15](https://github.com/Bajena/ams_lazy_relationships/pull/15) ([willcosgrove](https://github.com/willcosgrove))

## [v0.1.1](https://github.com/Bajena/ams_lazy_relationships/tree/v0.1.1) (2019-01-09)
[Full Changelog](https://github.com/Bajena/ams_lazy_relationships/compare/v0.1.0...v0.1.1)

**Merged pull requests:**

- Relax batch-loader version [\#13](https://github.com/Bajena/ams_lazy_relationships/pull/13) ([Bajena](https://github.com/Bajena))

## [v0.1.0](https://github.com/Bajena/ams_lazy_relationships/tree/v0.1.0) (2018-12-30)
**Closed issues:**

- Add changelog [\#10](https://github.com/Bajena/ams_lazy_relationships/issues/10)
- Prepare initial version + test suite [\#2](https://github.com/Bajena/ams_lazy_relationships/issues/2)
- Test multiple AMS versions [\#1](https://github.com/Bajena/ams_lazy_relationships/issues/1)

**Merged pull requests:**

- Add undercover back [\#12](https://github.com/Bajena/ams_lazy_relationships/pull/12) ([Bajena](https://github.com/Bajena))
- Add changelog [\#11](https://github.com/Bajena/ams_lazy_relationships/pull/11) ([Bajena](https://github.com/Bajena))
- Split methods logically, add yard comments and hide unnecessary public methods [\#9](https://github.com/Bajena/ams_lazy_relationships/pull/9) ([Bajena](https://github.com/Bajena))
- Code cleanup [\#8](https://github.com/Bajena/ams_lazy_relationships/pull/8) ([Bajena](https://github.com/Bajena))
- Add tests for JSON adapter and improve backwards compatibility [\#7](https://github.com/Bajena/ams_lazy_relationships/pull/7) ([Bajena](https://github.com/Bajena))
- Use Appraisal to test different versions of AMS [\#6](https://github.com/Bajena/ams_lazy_relationships/pull/6) ([Bajena](https://github.com/Bajena))
- Add core module [\#5](https://github.com/Bajena/ams_lazy_relationships/pull/5) ([Bajena](https://github.com/Bajena))
- Add Loader classes [\#4](https://github.com/Bajena/ams_lazy_relationships/pull/4) ([Bajena](https://github.com/Bajena))
- Initial setup [\#3](https://github.com/Bajena/ams_lazy_relationships/pull/3) ([Bajena](https://github.com/Bajena))



\* *This Change Log was automatically generated by [github_changelog_generator](https://github.com/skywinder/Github-Changelog-Generator)*