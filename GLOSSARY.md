# ansible-hindsight

An Ansible role that installs and configures Hindsight, Vectorize's agent memory engine, on a Linux host.

## Language

**Hindsight**:
The agent memory engine from Vectorize that this role deploys.
_Avoid_: hindight, the memory service

**Hindsight Server**:
The running Hindsight process that exposes the memory API to agents.
_Avoid_: backend, daemon

**Control Plane**:
Hindsight's web UI for inspecting and administering a Hindsight Server.
_Avoid_: dashboard, admin panel

**Embedded Database**:
The Postgres instance Hindsight bundles and manages itself, used when no external database is configured.
_Avoid_: built-in DB, pg0 (an implementation name)

**External Database**:
A user-provided PostgreSQL with a vector extension that a Hindsight Server is pointed at. The role never installs or manages it.
_Avoid_: remote DB

**Target Host**:
A Linux machine on which the role installs Hindsight.
_Avoid_: node, server (ambiguous with Hindsight Server)
