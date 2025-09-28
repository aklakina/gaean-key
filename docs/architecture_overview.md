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

# Project Structure

```
Gaeam Key/
├── main.tf                                # Main entry point for Terraform
├── credential_rotation_architecture.puml  # Architecture diagram
├── README.md                              # This documentation
├── constants/                             # Shared Terraform outputs and constants
├── modules                                # Core Terraform engine
│   ├── load_configs/                      # Configuration loading
│   ├── get/                               # Secret retrieval functionality
│   ├── rotate/                            # Secret rotation functionality
│   └── deploy/                            # Secret deployment functionality
├── configurations/                        # service-specific configurations
│   └── <service>/                         # service-specific configuration folders
│       ├── deployment/                    # Deployment configurations
│       ├── rotation/                      # Rotation configurations
│       └── get/                           # Retrieval configurations
└── extensions/                            # Service-specific implementations
    └── <service>/                         # Service-specific extension folders
        ├── deployment/                   # Deployment component
        ├── rotation/                     # Rotation component
        └── get/                           # Get component
```
