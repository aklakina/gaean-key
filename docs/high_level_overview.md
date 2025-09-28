# High Level Overview

## Main Components

The system consists of three primary parts that work together:

1. **Configuration loading**: Loads configurations from all extensions
2. **Secret Loading**: Includes rotation and retrieval of secrets
3. **Secret Utilization**: Handles storage and deployment of secrets

## Extension Architecture

Each extension provides implementations for some or all of these components:

- **Rotation**: Logic to rotate credentials for a specific service
- **Get**: Logic to retrieve credentials from a service
- **Deployment**: Logic to deploy credentials to target systems

These components expect and provide data in a specific way to and from the core engine. Following this method ensures data integrity throughout the system and credential flow while still allowing independent workflow for each service and each component.