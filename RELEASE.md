# Release steps
1. Bump VERSION constant
2. Generate changelog and update
```shell
CHANGELOG_GITHUB_TOKEN=<token> bundle exec rake changelog
```
3. Run `bundle` to regenerate Gemfile.lock
4. Commit & push a new tag
5. Build and push to rubygems
```shell
gem build ams_lazy_relationships
gem push ams_lazy_relationships-x.y.z.gem
```
