# Bowie

Bowie is an [Apache v2] GenServer-based module that listens to your
CouchDB Changes feed, based off the amazing [Mint] library.

[Mint]: http://hex.pm/packages/mint
[Apache v2]: https://apache.org/licenses/LICENSE-2.0.html

## Features

- [ ] OTP friendly GenServer
- [ ] transparently handles network connectivity failures
- [ ] include fully parsed document bodies, or not
- [ ] jump-start from a given `sequence token` instead of the beginning of
    time
- [ ] provides overrideable handler
- [ ] inline code documentation

## Usage

While Bowie can be used directly, in the iex console, it is designed to drop
into a typical OTP Supervisor tree and receive a stream of changes from it's
linked ibrowse worker.

There is one overrideable function, `handle_changes/1` which receives a
parsed JSON document, upon every notified change.

When your worker is initialised, the well-known CouchDB changes feed
parameters are supported:

- `include_docs: true` to include the entire JSON-parsed document
- `since: <seq>`, the sequence token of the database to start streaming from
- `headers: [{:atom, "string"}]` include arbitrary headers to every request
-
Note that in all cases, you will need to handle attachments yourself, as
a separate CouchDB call - it it makes no sense to stream potentially
MB or GB of attachment data inefficiently as Base64 encoded data from
server to client.

Let's make an example Bowie Changes worker:

```elixir
couch_uri = "http://admin:passwd@127.0.0.1:5984/mydb"
ziggy = Bowie.connect!(couch_uri)
flags = [include_docs: true, since: :now]
args = ...
workers = [%{id: My.Worker, start: {Bowie, :start_link, args}}]
options = [strategy: :one_for_one, name: My.Supervisor]
Supervisor.start_link( workers, options )
```

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `bowie` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:bowie, "~> 0.10.0"}
  ]
end
```

## [Apache v2] license

Copyright 2018-2038, SkunkWerks, GmbH

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
