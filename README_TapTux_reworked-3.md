# TapTux — Official Project

> **[TapTux]() delivers multiple desktop environments through lightweight, custom-built OS containers designed to run on mobile devices.**
> It is designed to work offline and focuses on providing a practical desktop experience with a low-level, resource-conscious architecture.

## Contents

- [Executive Summary](#executive-summary)
- [Project Editions & Installation](#project-editions--installation)
- [Security & Privacy](#security--privacy)
- [Requirements & Operational Structure](#requirements--operational-structure)
- [Developers & Contributors](#developers--contributors)

---

# Executive Summary

> **TapTux** is a **modular platform** that delivers multiple desktop environments through lightweight, custom-built OS containers.

TapTux combines container-based isolation with low-level system-oriented components. Part of its architecture is built around **low-level emulation and abstraction**, allowing system behavior, resource handling, and isolated environments to be modeled without requiring a traditional full virtual machine for every workload.

- **Independent Application:** Runs fully standalone as a native package. ```BETA, NOT AVAILABLE```
- **[Termux](https://github.com/termux/termux-app)** Support: Designed for seamless operation alongside Termux environments. ```AVAILABLE SOON```
- **Mobile & Embedded Ready:** Optimized for efficient operation across mobile and embedded devices.
- **Low-Level Architecture:** Uses lightweight system-facing components for isolation, resource management, and environment control.
- **Emulation-Oriented Design:** Provides low-level emulation and abstraction layers for system-style behavior inside isolated environments.
- **Performance & Configurability:** Designed to keep resource usage practical while allowing the environment to be configured to suit different workloads.
- **Developer-Friendly:** Maintains a modular, predictable architecture intended to be easy to extend and maintain.

---

## Project Editions & Installation

### 1. TapTux (CLI)

* **Features:** Lightweight command-line interface, low resource overhead, direct interaction with the `sysguard` isolation layer, and scripting support for headless or embedded deployments.

```bash
TapTux CLI - Initial Release Scheduled
ETA: 29 Sept, 2026
```

### 2. TapTux (TUI)

* **Features:** Terminal-based user interface, interactive navigation, real-time container monitoring, and streamlined workspace management. 

```bash
TapTux TUI - Initial Release Scheduled
ETA: The release has not been scheduled due to incomplete work
```

### 3. TapTux (GUI)

* **Features:** Provides a desktop-oriented user experience tailored for Android devices. Beyond container management, TapTux GUI is designed to host familiar desktop environments alongside custom-built environments developed for mobile form factors. It uses a C-based nested window architecture with local sockets, file-bridging mechanisms for controlled data transfer, and low-level system components for managing isolated graphical workloads.

```bash
TapTux GUI - Initial Release Scheduled
ETA: The release has not been scheduled due to incomplete work
```

---

# Security & Privacy

**Security Architecture & Isolation Framework:**

TapTux is designed with isolation as a core architectural principle. The security model focuses on keeping containerized workloads separated from the host environment while minimizing the amount of privileged infrastructure required.

- **Low-Level Rootless Isolation (sysguard):** Operating in user space without requiring root privileges, `sysguard` works at the system-call and runtime boundary to provide tightly scoped isolation for containerized environments. The goal is to keep experimental or untrusted workloads inside their designated environment and limit their access to the host system.

- **Nested Graphical Isolation:** Modular graphical environments can be managed through low-level C-based control structures, helping keep GUI workloads within their intended boundaries and reducing unnecessary access to host display resources.

- **Runtime Monitoring:** The architecture can include background monitoring for filesystem, process, and network activity so that unusual operations can be detected and handled as part of the isolation layer.

> **Security Advisory:** Security controls are intended to provide additional isolation and monitoring, but they should not be treated as a guarantee of complete protection. Disabling protective components or running untrusted software can increase the risk of system or data compromise.

---

# Requirements & Operational Structure

- **Resource Orchestration:** TapTux monitors available device resources such as RAM, CPU capacity, and battery state to help manage workloads efficiently.

- **Hardware-Aware Throttling:** Resource limits can be applied to CPU and memory usage to reduce unnecessary load and maintain a more consistent experience on mobile hardware.

- **Power Awareness:** The architecture is designed to avoid unnecessary background consumption and to account for the power constraints of mobile devices.

- **Expanded Usability:** Resource and power management are intended to make longer desktop sessions more practical on supported devices.

**Requirements:**
> TapTux is intended to run on Android devices with a minimum baseline of **Android 8**, **16GB of available storage**, and **1GB of RAM**. These requirements represent the minimum target configuration for the platform and its isolated environments, while actual resource usage can vary depending on the desktop environment, running workloads, and the number of active containers.

# Developers & Contributors

> The project is officially managed and directed by a specialized group of developers operating under the organization name **UniSoft**. The initiative is spearheaded by the primary owner and project team leader, **```Mikhail M. Abdelaziz```**, in strategic collaboration with **```(Bulgarian Vyasheslav, also known as JotarOS)```**, **```Avital Shalev```**, **```Tasuni Nagashita```** And **```Raed Abdullah```**.
