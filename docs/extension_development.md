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

The engine **always** passes the defined configurations as a parameter to the component (named `configurations`, `configs`, or `configuration`: the stack sync script uses whichever of these the component declares). If none is declared, `scripts/sync_stacks.py` fails.

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

If the rotation component declares a `secrets` variable, the engine passes it the credentials the configuration references (any nested `{service, id}` mapping, e.g. `parent: {service: x, id: y}`), so a rotation can depend on another credential (e.g. use one credential to mint another). The same holds for Get components.

##### Wiring

None. Every rotation configuration becomes its own stack (`stacks/<service>/rotation/<id>/`) whose generated code runs the component as a `phase1`/`phase2` module pair, driven by `modules/rotation_schedule`. Each phase instance receives `{ "<id>" = <config> }` and the engine reads `secret["<id>"]` (or `secrets["<id>"]`) of the active phase, so key the output by the configuration key.

#### Deployment

##### Configurations

The deployment configurations are organized into sub-type folders within the `deployment/` directory of a service. Each sub-type folder is one deployment unit and one stack (`stacks/<service>/deployment/<sub_type>/`). The engine uses the config processor (`modules/config_processor.jinja2`) to build a nested map from the folder structure and passes the sub-type's subtree to the deployment component: `configurations/<service>/deployment/<sub_type>/<group>/<name>.yml` becomes `configurations.<group>.<name>` of the `<sub_type>` stack (the same map the component got per sub-type before the move to stacks).

Every deployment configuration also gets a `config_file` key with its path relative to the repo root (e.g. `configurations/test_service/deployment/consumer1/a/consume1.yml`), for example to put a "managed by" notice on the deployed resources. Typed `object` variables simply drop it if the extension does not declare it.

##### Inputs

The `secrets` input only contains the credentials the unit's configurations reference (plus the `none`/`TBD` placeholders), as `service => id => {username, secret}`.

The sync script already rejects references to credentials that nothing produces. Consumers should still fail the plan with a clear message when a config references a credential that isn't in `secrets` (e.g. when the component is used outside the engine or in its tests): compare against the plan-time-known ids (`nonsensitive({ for s, c in var.secrets : s => keys(c) })`) in a `precondition`, as the `github` and `azure_keyvault` extensions do.

A Store component (`extensions/<service>/store/`) serves the `deployment/` configurations of its service exactly like a Deployment component; the engine uses `deployment/` if both exist.

#### Extension providers

There is no root module to declare provider aliases in any more: every stack has its own root module and configures only the providers of its own extension. A component that needs a configured provider ships a `gaean.tm.hcl` next to its `.tf` files (imported by every stack using it) with the provider block and the provider's source; see [Stacks](./stacks.md#provider-configuration) and `extensions/gitlab/rotation/gaean.tm.hcl`. Configure credentials through the provider's environment variables, non-secret settings through the global `provider_settings.<provider>`. Different instances of a service (e.g. several organizations) get their settings per stack folder.

#### Adding an extension

1. Implement the component(s) in `extensions/<service>/<component>/` following the constraints above, plus a `gaean.tm.hcl` if it needs a provider.
2. Add unit tests in `extensions/<service>/<component>/tests/*.tftest.hcl` with `mock_provider` blocks (they run against the component itself: `tofu -chdir=extensions/<service>/<component> test`), and an example configuration in `examples/configurations/<service>/`.
3. Add configurations under `configurations/<service>/<stage>/`.
4. Run `python scripts/sync_stacks.py` and `terramate generate`, and commit the result.

The sync script detects the configuration variable name and the output name from the component's `.tf` files and fails with a clear error if the contract is not met. The extensions in [Available Extensions](./available_extensions.md) make good templates.
