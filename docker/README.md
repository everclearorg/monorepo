Docker directories named according to Everclear packages.

Config.json located in the root of each project's docker ie (repo-root)/docker/<project name> controls how the packages will be configured. for examples see (repo-root)/packages/examples.config.json

Run everything from the root directory.

> NOTE: If you are using an M1/M2 mac, you must provide the flag "`--platform linux/amd64`"! Also if you are using Docker Desktop, make sure you turn ON the "Use Virtualization framework" option in Settings > General and turn OFF the "Use Rosetta for x86/amd64 emulation on Apple Silicon" option in Settings > Features in development.

Run:

```
docker run -it relayer-poller
```
