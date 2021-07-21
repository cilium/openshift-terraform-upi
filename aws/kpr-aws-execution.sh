kubectl create --namespace="${namespace}" --filename="-" << EOF
apiVersion: terraform.cilium.io/v1alpha1
kind: Execution
metadata:
  name: ${execution_name}
  namespace: ${namespace}
spec:
  moduleRef:
    kind: Module
    name: openshift-upi-aws
  image: docker.io/errordeveloper/terraform-runner:d7bed26
  submodulePath: aws
  interval: 20s
  jobBackoffLimit: 2
  convertVarsToSnakeCase: false
  variables:
    secretNames:
      - aws-cluster-secret
    extraVars:
      cluster_name: ${name}
      openshift_version: ${openshift_version}
      openshift_distro: ${openshift_distro}
      cilium_version: ${cilium_version}
      without_kube_proxy: true
EOF
