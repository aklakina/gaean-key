# Architecture Overview

The system follows a modular architecture with these core components:

1. **Main Entry Point**: Central configuration and orchestration
2. **Core Engine**: Handles the parsing and loading of configurations and data  to extensions
3. **Extensions**: Service-specific implementations for various platforms
4. **Shared Resources**: Common constants and utilities

```
┌─────────────┐                  
│  Main Entry │                  
│    Point    │                  
└─────┬───────┘                  
      │ Calls                         
      ▼                          
┌─────────────────────────────┐  
│         Core Engine         │  
├─────────┬─────────┬─────────┤  
│  Init   │ Secret  │ Secret  │  
│         │ Loading │ Usage   │  
└─────────┴────┬────┴────┬────┘  
               │         │       
       ┌───────┴─────────┘
       ▼     Implemented by
┌─────────────┐         ┌─────────────┐ 
│ Extensions  │ Used by │ Shared      │
│             │<--------│ Resources   │
└─────────────┘         └─────────────┘
```

## Architecture Diagram

How configurations flow through the engine into the extensions:

```mermaid
---
title: Gaean Key Architecture
---
flowchart TB
    subgraph entry["Main Entry Point"]
        Main["main.tf"]
    end

    subgraph configurations["configurations/"]
        subgraph service_configs["#lt;service#gt;/"]
            get_configs["get/"]
            rotation_configs["rotation/"]
            deployment_configs["deployment/"]
        end
    end

    subgraph engine["Core Engine (modules/)"]
        subgraph init["Init"]
            load_configs["Load configs"]
        end
        subgraph loading["Secret loading"]
            get["get"]
            rotate["rotate"]
            secret_map[("secrets")]
        end
        subgraph usage["Secret utilization"]
            deploy["deploy"]
        end
    end

    subgraph extensions["Extensions (extensions/)"]
        subgraph service_extensions["#lt;service#gt;/"]
            ext_get["get/"]
            ext_rotation["rotation/"]
            ext_deployment["deployment/"]
        end
    end

    subgraph shared["Shared Resources"]
        Constants["constants/"]
        shared_note["Contains shared constants used across the entire architecture"]:::note
    end

    %% Main flow
    Main -->|loads configurations| load_configs
    load_configs -->|"configs.get"| get
    load_configs -->|"configs.rotation"| rotate
    load_configs -->|"configs.deployment"| deploy
    get --> ext_get
    get --> secret_map
    get -->|retrieved secrets| rotate
    rotate --> ext_rotation
    rotate --> secret_map
    secret_map -->|var.secrets| deploy

    %% Configuration discovery
    get_configs --> load_configs
    rotation_configs --> load_configs
    deployment_configs --> load_configs

    %% Deployment targets
    deploy -->|deploys credentials| ext_deployment

    %% Shared resources
    Constants -. used by .-> service_extensions

    classDef note fill:#fff8c4,stroke:#c9b458,stroke-dasharray: 4 3,color:#333
```

# Project Structure

```
Gaean Key/
├── main.tf                                # Main entry point for OpenTofu
├── versions.tf                            # Required providers and provider configuration
├── README.md                              # This documentation
├── constants/                             # Shared OpenTofu outputs and constants
├── docs/adr/                              # Architecture decision records
├── modules                                # Core OpenTofu engine
│   ├── config_processor.jinja2            # Jinja2 template rebuilding the folder hierarchy of configs
│   ├── load_configs/                      # Configuration loading (incl. service.yml defaults)
│   ├── get/                               # Secret retrieval functionality
│   ├── rotate/                            # Secret rotation functionality (dual-phase; modules.tf wires the extensions, providers.tf their gated providers)
│   └── deploy/                            # Secret deployment functionality (providers.tf: gated providers)
├── examples/configurations/               # Example configurations of the bundled extensions
├── tests/                                 # tofu test suites (engine end-to-end, extensions with mock providers)
├── configurations/                        # service-specific configurations
│   └── <service>/                         # service-specific configuration folders
│       ├── service.yml                    # (Optional) defaults merged under every config of the service
│       ├── deployment/                    # Deployment configurations
│       ├── rotation/                      # Rotation configurations
│       └── get/                           # Retrieval configurations
└── extensions/                            # Service-specific implementations
    └── <service>/                         # Service-specific extension folders
        ├── deployment/                   # Deployment component
        ├── rotation/                     # Rotation component
        └── get/                           # Get component
```
