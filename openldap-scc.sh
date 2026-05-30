oc adm policy add-scc-to-user anyuid \
  -z openldap-sa \
  -n openldap
