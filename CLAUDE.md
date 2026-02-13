# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

callable-mixin is a Ruby gem providing a `Callable` module that gives classes a `.call` class method (instantiate + invoke) and `.to_proc` for `&ClassName` shorthand. Zero runtime dependencies. Supports Ruby 2.3+.

## Commands

```sh
bundle exec rspec                    # run full test suite
bundle exec rspec spec/callable_spec.rb:42  # run single test by line number
bundle exec rake spec                # run specs via rake
bundle exec rake multi:spec          # test against all supported Ruby versions (requires rbenv)
bundle exec rake changelog           # regenerate CHANGELOG.md
```

## Architecture

The entire implementation is ~60 lines in a single module:

- `lib/callable/mixin.rb` — Core `Callable` module with `ClassMethods` (`.call`, `.to_proc`) and `ConstructionError`
- `lib/callable.rb` — Requires version and mixin
- `lib/callable-mixin.rb` — Alternate entry point (requires `callable`)
- `spec/callable_spec.rb` — Comprehensive spec covering parameter variations, block forwarding, error handling, and `to_proc`

### How it works

Including `Callable` in a class triggers `self.included`, which `extend`s the class with `ClassMethods`. This adds:

- `.call(*args, &block)` — Forwards args to `initialize` via `ruby2_keywords`, then calls `#call(&block)` on the instance. Blocks go to `#call`, not `initialize`.
- `.to_proc` — Returns `method(:call).to_proc` for `&ClassName` syntax.

### Error handling semantics

- **Exact** `ArgumentError` from `initialize` → wrapped in `ConstructionError` (preserves backtrace)
- `ArgumentError` subclasses from `initialize` → propagated unwrapped
- Any error from `#call` → propagated unwrapped
- Missing `#call` instance method → `NotImplementedError`

Uses `instance_of?(ArgumentError)` intentionally (not `is_a?`) to distinguish constructor arity mismatches from domain errors.

### Ruby 2.7 kwargs compatibility

The `.call` method uses `ruby2_keywords` (when available) so that hash-style keyword arguments pass through transparently without triggering Ruby 2.7 deprecation warnings or Ruby 3.x argument errors.

## Conventions

- Frozen string literals in all files
- RSpec with `disable_monkey_patching!` and `expect` syntax only
- No runtime dependencies — gemspec dev deps are rspec and rake only (Gemfile also includes github_changelog_generator)
- `##` style documentation comments in source
