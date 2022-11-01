# CMS

[![Package](https://img.shields.io/hexpm/v/cms.svg)](https://hex.pm/packages/cms) [![Documentation](http://img.shields.io/badge/hex.pm-docs-green.svg?style=flat)](https://hexdocs.pm/cms) ![CI](https://github.com/balexand/cms/actions/workflows/elixir.yml/badge.svg)

For fetching data from any headless CMS with an ETS cache for lightning fast response times.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cms` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cms, "~> 0.7"}
  ]
end
```

## Usage

TODO

## Telemetry

The following telemetry is emitted:

* `[:cms, :update, :start]`, `[:cms, :update, :stop]`, and `[:cms, :update, :exception]` - Span events for CMS updates.
