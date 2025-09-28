# Secret Flow

The secret flow follows this pattern:

1. Configuration is loaded from the extensions (Engine)
2. Secrets are rotated using service-specific rotation logic (Rotation component)
3. Secrets are retrieved from credential management systems (Get component)
4. Rotated and retrieved secrets are stored in a central secret map (Engine)
5. Secrets are deployed to target systems as configured (Deployment component)

## Components and their purposes

For detailed explanations and examples of each component, please refer to the [Extension Development](./extension_development.md) documentation.

### Get

The Get component of any extension is responsible for retrieving existing secrets from a credential management system. This could be systems like Vault, AWS Secrets Manager, or any other supported secret storage service.

### Rotate

The output of the Rotate component is the same as the Get component, a map of secrets usable by other components. However, the Rotate component also signals that the framework itself is responsible for the lifecycle of the secret.

### Deployment

The Deployment component is responsible for taking secrets and deploying them to target systems. This could involve updating configuration files, environment variables, or any other method of injecting secrets into applications or services.
