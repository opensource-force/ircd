## Intro
Although Nim is multi-paradigm and supports a wide range of formatting, for the sake of consistency we refer to official [Nim style guide](https://nim-lang.org/docs/nep1.html) but with less strict enforcements

## Spacing
- 4 spaces (not tabs)
- Lines should be no longer than 80 characters

## Naming Conventions
Constants and type identifiers are PascalCase; Other identifiers are camelCase

## Coding Conventions
- Use `let` instead of `var` for immutable variables where possible
- Prefer proc over more powerful macros, templates, iterators, and converters
- use `parseUrl` over `parseURL`, `checkHttpHeader` over `checkHTTPHeader`
- Use subjectVerb, not verbSubject, e.g.: `fileExists`, not `existsFile`