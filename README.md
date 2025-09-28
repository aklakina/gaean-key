# Gaean Key

[![Terraform Tests](https://github.com/aklakina/gaean-key/actions/workflows/terraform-tests.yml/badge.svg)](https://github.com/aklakina/gaean-key/actions/workflows/terraform-tests.yml)

A comprehensive, modular Terraform-based system for automated credential rotation across multiple platforms and services.
The system uses an extensible architecture to support various credential providers, and deployment targets through pluggable extensions
while maintaining an isolated extension environment.

## Why Gaean Key?

Managing and rotating credentials is a critical aspect of maintaining security in any infrastructure. Gaean Key provides a structured and automated approach to handle this complex task, ensuring that credentials are rotated regularly and securely across different services.
Unlike other solutions, Gaean Key is designed to be a multi-cloud, multi-service framework that can be easily extended to support new services and deployment targets.
This makes it a versatile choice for organizations with diverse infrastructure needs.

## Documentation

1. [Quick Start](./docs/quick_start.md)
2. [High Level Overview](./docs/high_level_overview.md)
3. [Architecture Overview](./docs/architecture_overview.md)
4. [Secret Flow](./docs/secret_flow.md)
5. [Extension Development](./docs/extension_development.md)
6. [Available Extensions](./docs/available_extensions.md)
7. [Troubleshooting](./docs/troubleshooting.md)

## License

Licensed under the MIT License