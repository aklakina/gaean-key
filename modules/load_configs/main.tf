locals {
  deployment_flat_configs = [
    for file_path in fileset("${path.module}/../../configurations", "*/deployment/**/*.yml") : {
      service = split("/", file_path)[0]
      path_segments = slice(
        split("/", replace(file_path, "${split("/", file_path)[0]}/deployment/", "")),
        0,
        length(split("/", replace(file_path, "${split("/", file_path)[0]}/deployment/", ""))) - 1
      )
      config_name = replace(element(split("/", file_path), -1), ".yml", "")
      config = merge(
        try(yamldecode(file("${path.module}/../../configurations/${split("/", file_path)[0]}/service.yml")), {}),
        yamldecode(file("${path.module}/../../configurations/${file_path}")),
        # repo-relative path of the file, e.g. for "managed by" notices on the deployed resources
        { config_file = "configurations/${file_path}" }
      )
    }
  ]

  # For rotation stage, create a flat dictionary with relative path as key
  rotation_flat_configs = {
    for file_path in fileset("${path.module}/../../configurations", "*/rotation/**/*.yml") :
    replace(replace(file_path, "/rotation", ""), ".yml", "") =>
    merge(
      try(yamldecode(file("${path.module}/../../configurations/${split("/", file_path)[0]}/service.yml")), {}),
      yamldecode(file("${path.module}/../../configurations/${file_path}"))
    )
  }
  get_flat_configs = {
    for file_path in fileset("${path.module}/../../configurations", "*/get/**/*.yml") :
    replace(replace(file_path, "/get", ""), ".yml", "") =>
    merge(
      try(yamldecode(file("${path.module}/../../configurations/${split("/", file_path)[0]}/service.yml")), {}),
      yamldecode(file("${path.module}/../../configurations/${file_path}"))
    )
  }
}

data "jinja_template" "parse_configs" {

  context {
    type = "yaml"
    data = yamlencode({
      stage        = "deployment",
      flat_configs = local.deployment_flat_configs
    })
  }
  source {
    template  = file("${path.module}/../config_processor.jinja2")
    directory = path.module
  }
}

locals {
  configs = merge(
    {
      deployment = jsondecode(data.jinja_template.parse_configs.result)
    },
    {
      rotation = local.rotation_flat_configs
    },
    {
      get = {
        for top, items in {
          for key, item in local.get_flat_configs : (strcontains(key, "/") ? split("/", key)[0] : "/") => {
            key = strcontains(key, "/") ? join("/", slice(
              split("/", key),
              1,
              length(split("/", key))
            )) : key
            content = item
          }...
        } : top => { for item in items : item.key => item.content }
      }
    }
  )
}