# routeros examples

One runnable example per topic - `<topic>.j` for each topic file under
`src/topics/`. Each connects, **reports** that topic's state read-only,
and shows the mutating calls as comments, so running one against a real
router changes nothing.

```sh
MT_HOST=192.168.88.1 MT_USER=admin MT_PASSWORD=secret jennifer run examples/firewall.j
```

All examples import the module the same way (`import "../src/routeros.j"
as mt`) and take credentials from the `MT_HOST` / `MT_USER` /
`MT_PASSWORD` environment variables.

For the concepts behind each, see the matching guide in
[../docs/](../docs/README.md); for the full API surface, the
[cheatsheet](../docs/cheatsheet.md).
