module installer {
  # it assumed that these UPI templates are broadly compatible with any OKD or OCP version, so the revision here
  # should be just some recent commit and there is no need to map it to openshift_version/openshift_distro
  source = "git::https://github.com/openshift/installer.git?ref=a6597edd93133f88bb5280a3cd0660f25e8d77e9"
}

data local_file modules_json {
  filename = format("%s/.terraform/modules/modules.json", abspath(path.root))
}

locals {
  # extract path to installer repo checkout by reading modules.json
  modules_list =  jsondecode(data.local_file.modules_json.content)["Modules"]
  # match the key that has `installer` suffix
  installer_path = [ for m in local.modules_list: m.Dir if trimsuffix(m.Key, "installer") != m.Key ][0]
}
