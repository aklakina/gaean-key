locals {
  flat_configs = {
    for stage in ["deployment", "rotation", "get"] : stage => [
      for file_path in fileset("${path.module}/../../configurations", "*/${stage}/**/*.yml") : {
        service = split("/", file_path)[0]
        path_segments = slice(
          split("/", replace(file_path, "${split("/", file_path)[0]}/${stage}/", "")),
          0,
          length(split("/", replace(file_path, "${split("/", file_path)[0]}/${stage}/", ""))) - 1
        )
        config_name = replace(element(split("/", file_path), -1), ".yml", "")
        config      = yamldecode(file("${path.module}/../../configurations/${file_path}"))
      }
    ]
  }
}

data "jinja_template" "parse_configs" {
  for_each = toset(["deployment", "rotation", "get"])

  context {
    type = "yaml"
    data = yamlencode({
      stage        = each.key,
      flat_configs = local.flat_configs[each.key]
    })
  }
  source {
    template  = file("${path.module}/config_processor.j2")
    directory = path.module
  }
}

locals {
  configs = merge({
    for stage in ["deployment", "rotation", "get"] :
    stage => jsondecode(data.jinja_template.parse_configs[stage].result)
  })
}