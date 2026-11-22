# Extension Development

<!-- TOC -->
* [Extension Development](#extension-development)
  * [Extension Structure](#extension-structure)
  * [Configuration Structure](#configuration-structure)
  * [Extension Requirements](#extension-requirements)
    * [Generic constraints](#generic-constraints)
    * [Component type specific constraints](#component-type-specific-constraints)
      * [Providers](#providers)
      * [Consumers](#consumers)
    * [Component specific constraints](#component-specific-constraints)
      * [Rotation](#rotation)
        * [Configurations](#configurations)
        * [Inputs](#inputs)
        * [Wiring](#wiring)
      * [Extension providers](#extension-providers)
      * [Deployment](#deployment)
        * [Configurations](#configurations-1)
        * [Inputs](#inputs-1)
<!-- TOC -->

## Extension Structure

An extension should implement one or more of these components:

```
extensions/<service>/
├── deployment/          # Deployment component
├── rotation/            # Rotation component
└── get/                 # Get component
```

> **Note**: Not all components need to be implemented. Each extension should implement only the components relevant to its service.

## Configuration Structure

Configurations are YAML files in the `configurations/` directory at the project root, organized by service and stage:

```
configurations/
└── <service>/
    ├── service.yml           # (Optional) Shared service-level config merged into all configs
    ├── deployment/           # Deployment configurations
    │   └── <sub_type>/       # Sub-type grouping, the folder hierarchy is preserved
    │       └── <name>.yml
    ├── rotation/             # Rotation configurations
    │   └── <name>.yml
    └── get/                  # Retrieval configurations
        └── <name>.yml
```

Only files ending in `.yml` are loaded, so a configuration can be disabled by renaming it (e.g. to `<name>.yml.old`).

When a `service.yml` file exists in a service folder, its contents are merged as defaults into every configuration file of that service. The individual configuration file values take precedence over the service-level defaults.

## Extension Requirements

Each extension component must adhere to the structure expected by the core engine:
### Generic constraints

The engine **always** passes the defined configurations as a parameter to the component (named `configurations`, `configs`, or `configuration`, depending on how the component is wired in `modules/`). If this is not defined as a variable, OpenTofu will fail to run the project.

The engine always provides the configurations defined by the extension and the component **exclusively**. This means each component can have a typed definition for the configuration it expects.

> [!Example] Example configuration and variable definition
> For example for this configuration file:
> ```yml
> url: https://org.com/app
> username: service-usr@org.com
> groups:
>   - admin # let's assume this is optional for the sake of example
> ```
> One would define the `variables.tf` as follows:
> ```hcl
> variable "configurations" {
> 	  type = map(object({
> 		  url = string
> 		  username = string
> 		  groups = optional(list(string), [])
> 	  }))
> }
> ```

Every configuration passed from the engine to the component can be treated as deterministic, plan-time-known values. This means meta arguments such as `life_cycle`, `for_each`, `count` can work with the content of this variable.

### Component type specific constraints

In addition to generic constraints and expectations, the engine expects additional things based on the type of the service component.

Components can be grouped into two distinct types.
1. **Providers**: Get, Rotation
2. **Consumers**: Deployment (and Store)

Additionally, to the `configurations` object the engine passes to the modules, these types are expected to also handle and provide specific outputs in a specific format.

#### Providers

Additionally to the generic constraints and requirements, Providers are expected to have an output property called `secret` (or `secrets`). The output should be a map where each entry contains at minimum `username` and `secret` properties. The keys of this map should either be constructed by the provider in a human readable manner, or simply use the key from the `configurations` input object as this will be the reference id for consumer components for the provided secrets.

#### Consumers

Additionally to the generic constraints and requirements, Consumers are expected to have an additional input property called `secrets`. This object contains every referenced secret based on the define configurations.


> [!Secret referencing] Referencing a secret
> A consumer configuration must have a property named `secret` which should be an object with two properties:
> - `service`
> - `id`
> In yaml:
> ```yml
> secret:
>   service: <provider_service>
>   id: <secret key outputted from the provider service>
> ```
> These properties shall uniquely identify a secret which is defined in any provider's configuration.
> The engine provides the placeholders `none/none` and `TBD/TBD` for consumers whose credential does not exist yet.

### Component specific constraints

In addition to generic and component type specific restrictions the engine also has additional restrictions and requirements based on the specific component. Components not listed here only have the Generic and the component type specific restrictions and requirements.

#### Rotation

##### Configurations

Every rotation configuration **must** include an `expires_in` property that defines how long a credential is valid (a duration such as `720h`; templates are evaluated, so `"${30*24}h"` works too). The engine uses it to drive the dual-phase rotation cycle described in [Secret Flow](./secret_flow.md#rotate).

An optional `rotation_window` property defines the overlap during which both the old and the new credential are valid. It defaults to 20% of `expires_in` and must be shorter than it.

The extension itself should create a credential valid for (at least) `expires_in`; the engine decides when it is replaced.

##### Inputs

The engine has the retrieved credentials (Get stage) available in the rotate module as `var.secrets`, so a rotation can depend on another credential (e.g. use one credential to mint another). Pass it to the extension if it needs it.

##### Wiring

Each rotated service needs a `phase1`/`phase2` module pair in `modules/rotate/modules.tf` (one instance per config, so a phase change only touches that config) and an entry in `modules/rotate/outputs.tf` that picks the active phase. Use `modules/rotate/modules.tf` and `outputs.tf` of `test_service` as the template. The output keeps the set of services and ids known at plan time; keep it that way (build the maps with `for` expressions, not `merge()` over whole module outputs).

If the extension needs a provider, add it to `modules/rotate/providers.tf` (see [Extension providers](#extension-providers)) and pass the gated instance to both phase modules with `providers = { <name> = <name>.rotation["default"] }`. Use the `aws`, `azuread` or `gitlab` pair as the template.

#### Extension providers

Extension providers are declared in the engine module that calls the extension (`modules/rotate/providers.tf`, `modules/deploy/providers.tf`), not in the root, with `for_each` over a set that contains `"default"` only while `configurations/<service>/` has a `.yml` file. A provider instance that doesn't exist is never configured, so users only need credentials for the services they use.

- Add the provider to the module's `versions.tf`, the service name to the `provider_instances` list in `providers.tf`, and a provider block with `alias` + `for_each = local.provider_instances["<service>"]`.
- Configure credentials through the provider's environment variables. Non-secret settings go into the root variable `provider_settings` (add an optional attribute there); a provider block needs at least one argument anyway, or OpenTofu treats it as a legacy proxy block.
- The set is computed with `fileset()` inside the engine module on purpose: provider `for_each` is evaluated statically and can't use module outputs.
- Deployment modules are instantiated with `for_each` over the provider's set, but only while they have configs (see `modules/deploy/main.tf`), so the provider outlives their resources when the last config is removed.

#### Deployment

##### Configurations

The deployment configurations are organized into sub-type folders within the `deployment/` directory of a service. The engine uses the config processor (`modules/config_processor.jinja2`) to build a nested map from the folder structure, which is then passed to the deployment extension: `configurations/<service>/deployment/<sub_type>/<group>/<name>.yml` becomes `configs.<service>.<sub_type>.<group>.<name>`.

Every deployment configuration also gets a `config_file` key with its path relative to the repo root (e.g. `configurations/test_service/deployment/consumer1/a/consume1.yml`), for example to put a "managed by" notice on the deployed resources. Typed `object` variables simply drop it if the extension does not declare it.

##### Inputs

In addition to the configurations and `secrets`, a deployment module may receive a provider. Declare it gated in `modules/deploy/providers.tf` (see [Extension providers](#extension-providers)) and pass it with `providers = { <name> = <name>.deployment[each.key] }`, like `github_actions_secret` in `modules/deploy/main.tf`. For several instances of the same service (e.g. two organizations), use two service folders and two gated provider blocks.

Consumers should fail the plan with a clear message when a config references a credential that doesn't exist: compare against the plan-time-known ids (`nonsensitive({ for s, c in var.secrets : s => keys(c) })`) in a `precondition`, as the `github` and `azure_keyvault` extensions do.
