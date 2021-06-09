resource google_storage_bucket cluster_boostrap_inginition_bucket {
  name = local.cluster_boostrap_inginition_bucket_name
  location = "EU"
  force_destroy = true
}

resource google_storage_bucket_object cluster_boostrap_inginition_object {
  name = "bootstrap.ign"
  bucket = google_storage_bucket.cluster_boostrap_inginition_bucket.name
  content = module.common.bootstrap_ign
}

data google_storage_object_signed_url cluster_boostrap_inginition_object_signed_url {
  depends_on = [ google_storage_bucket_object.cluster_boostrap_inginition_object ]
  bucket = google_storage_bucket.cluster_boostrap_inginition_bucket.name
  path = "bootstrap.ign"
  duration = "2h"
  credentials = local_file.master_service_account_key.filename
}

locals {
  cluster_boostrap_inginition_bucket_name = format("openshift-cilium-ci-%s-cluster-bootstrap", substr(sha256(local.infrastructure_name), 0, 24))
}
