# Extension Development

<!-- TOC -->
* [Extension Development](#extension-development)
  * [Extension Structure](#extension-structure)
  * [Extension Requirements](#extension-requirements)
    * [Generic constraints](#generic-constraints)
    * [Component type specific constraints](#component-type-specific-constraints)
      * [Providers](#providers)
      * [Consumers](#consumers)
    * [Component specific constraints](#component-specific-constraints)
        * [Deployment](#deployment)
          * [Configurations](#configurations)
          * [Inputs](#inputs)
<!-- TOC -->

## Extension Structure

An extension should implement one or more of these components:

```
configurations/<service>/
├── deployment/          # Deployment configurations
├── rotation/            # Rotation configurations
└── get/                 # Retrieval configurations
extensions/<service>/
├── deployments/         # Deployment component
├── rotations/           # Rotation component
└── get/                 # Get component
```

## Extension Requirements

Each extension component must adhere to the structure expected by the core engine:
### Generic constraints

The engine **always** passes the defined configurations as the **`configurations`** parameter for the component. If this is not defined as a variable, terraform will fail to run the project.

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
2. **Consumers**: Deployment

Additionally to the `configurations` object the engine passes to the modules, these types are expected to also handle and provide specific outputs in a specific format.

#### Providers

Additionally to the generic constraints and requirements, Providers are expected to have an output property called `secrets`. The `secrets` should always be a map of objects `username` and `secret` property. The keys of this map should either be constructed by the provider in a human readable manner, or simply use the key from the `configurations` input object as this will be the reference id for consumer components for the provided secrets.

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
