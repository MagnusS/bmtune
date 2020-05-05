# bmtune

Utility to check and adjust various Linux kernel settings to tune it for
benchmarking with one or more isolated CPU cores. This tool is *experimental*
and mainly intended to run as a LinuxKit onboot service.

To use `bmtune`, boot the kernel with `isolcpus`, `nohz_full`, as well as other
optimisations that may be needed (e.g. `rcu_nocbs`, `rcu_nocb_poll` and
parameters to disable power saving states).

The `ocaml_bench_scripts` [documentation](https://github.com/ocaml-bench/ocaml_bench_scripts/#notes-on-hardware-and-os-settings-for-linux-benchmarking) contains more details on what needs
to be configured and why.


When `bmtune` is executed, it will (without warning)

	1. Check that at least one core is isolated
	2. Disable Hyperthreading/SMT if enabled (should ideally be disabled in BIOS)
	3. Move IRQ handling away from the isolated cores
	4. Disable power saving and frequency scaling on the isolated cores

`bmtune` is designed to run on a minimal system and will currently not interact
with other running services, such as `irqbalance` or daemons that control power
saving. These will have to be configured/disabled independently.


A prebuilt image is a available on Docker hub. To use it as a LinuxKit onboot
service:

```
onboot:
  - name: bmtune
    image: ssungam/bmtune:latest
    ipc: host
    pid: host
    capabilities:
            - all
    command: ["/bmtune"]
```

## Building

The tool can be built as a command line utility or bundled in a
Docker-container suitable for LinuxKit integration.

### CLI tool

Requires `opam`, `dune` and a recent version of the OCaml compiler.

To build the command line utility:

```
$ make
```

The final binary will be in `_build/install/default/bin/bmtune`.

### LinuxKit service

This will build a statically linked binary and bundle it in a tagged Docker
container that can be referenced in a LinuxKit configuration file:

```
$ make static_docker
```

The final image will be tagged `bmtune:latest`. This can then be
included in a LinuxKit image:

```
onboot:
  - name: bmtune
    image: bmtune:latest
    ipc: host
    pid: host
    capabilities:
            - all
    command: ["/bmtune"]
```
