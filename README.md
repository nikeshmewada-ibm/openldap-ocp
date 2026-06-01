# OpenLDAP Server on OpenShift with phpLDAPadmin - Setup Guide

This guide provides step-by-step instructions to deploy an OpenLDAP server on OpenShift and use phpLDAPadmin to browse and manage it.

## Overview

This deployment includes:
- **OpenLDAP Server**: Directory service for user and group management
- **phpLDAPadmin**: Web-based LDAP browser and administration tool
- **Pre-configured Users & Groups**: CP4BA-related admin users and groups

## Prerequisites

- OpenShift cluster access with cluster-admin privileges
- `oc` CLI tool installed and configured
- Storage class available (default: `ocs-external-storagecluster-cephfs`)

## Architecture

- **Namespace**: `openldap`
- **LDAP Domain**: `expertlabs.ibm.com`
- **Base DN**: `dc=expertlabs,dc=ibm,dc=com`
- **Admin Password**: `passw0rd`

## Deployment Steps

### Step 1: Create Namespace

```bash
oc new-project openldap
```

### Step 2: Create Service Account

Apply the service account configuration:

```bash
oc apply -f openldap-sa.yml
```

### Step 3: Configure Security Context Constraints (SCC)

Grant the `anyuid` SCC to the service account (required for OpenLDAP container):

```bash
bash openldap-scc.sh
```

Or manually:

```bash
oc adm policy add-scc-to-user anyuid -z openldap-sa -n openldap
```

### Step 4: Create Persistent Volume Claims

Create PVCs for OpenLDAP data and configuration persistence:

```bash
oc apply -f openldap-data-pvc.yaml
oc apply -f openldap-config-pvc.yaml
```

**Note**: Update the `storageClassName` in both files if using a different storage class.

### Step 5: Create Bootstrap ConfigMap

Apply the LDIF bootstrap configuration containing initial users and groups:

```bash
oc apply -f ldap-bootstrap-ldif.yaml
```

This ConfigMap includes:
- Organizational Units (OUs): `users` and `groups`
- Admin users: `cp4baadmin`, `bawadmin`, `banadmin`, `fnadmin`
- Admin groups: `cp4ba-admins`, `odm-admins`, `fnwf-admins`, `fnwfcfg-admins`

### Step 6: Deploy OpenLDAP Server

Deploy the OpenLDAP server:

```bash
oc apply -f openldap-deployment.yaml
```

This deployment:
- Uses `osixia/openldap:1.5.0` image
- Exposes ports 389 (LDAP) and 636 (LDAPS)
- Mounts bootstrap LDIF files for initial data
- Uses persistent storage for data and configuration

### Step 7: Create OpenLDAP Services

Create the ClusterIP service for internal access:

```bash
oc apply -f openldap-svc.yaml
```

*Optional*: Create NodePort service for external access:

```bash
oc apply -f openldap-svc-np.yaml
```

### Step 8: Verify OpenLDAP Deployment

Check if the OpenLDAP pod is running:

```bash
oc get pods -n openldap
```

Check logs:

```bash
oc logs -f deployment/openldap -n openldap
```

### Step 9: Deploy phpLDAPadmin

Deploy the phpLDAPadmin web interface:

```bash
oc apply -f phpldapadmin-deployment.yaml
```

This deployment:
- Uses `osixia/phpldapadmin:0.9.0` image
- Connects to OpenLDAP via `openldap-svc.openldap.svc.cluster.local`
- Runs on HTTP (port 80)

### Step 10: Create phpLDAPadmin Service

```bash
oc apply -f phpldapadmin-svc.yaml
```

### Step 11: Create phpLDAPadmin Route

Create an OpenShift route to access phpLDAPadmin externally:

```bash
oc apply -f phpldapadmin-route.yaml
```

This creates an HTTPS route with edge termination.

### Step 12: Access phpLDAPadmin

Get the route URL:

```bash
oc get route phpldapadmin -n openldap
```

Access the URL in your browser.

## Accessing phpLDAPadmin

### Login Credentials

- **Login DN**: `cn=admin,dc=expertlabs,dc=ibm,dc=com`
- **Password**: `passw0rd`

## LDAP Connection Details

Use these details to connect applications to the LDAP server:

```
LDAP Server: openldap-svc.openldap.svc.cluster.local
Port: 389
Base DN: dc=expertlabs,dc=ibm,dc=com

User Search Base: ou=users,dc=expertlabs,dc=ibm,dc=com
Group Search Base: ou=groups,dc=expertlabs,dc=ibm,dc=com

```

For external access (if NodePort is enabled):
```
LDAP Server: <node-ip>
Port: 30389
```

## Pre-configured Users

| Username | DN | Email | Password |
|----------|-----|-------|----------|
| cp4baadmin | uid=cp4baadmin,ou=users,dc=expertlabs,dc=ibm,dc=com | cp4baadmin@expertlabs.ibm.com | passw0rd |
| bawadmin | uid=bawadmin,ou=users,dc=expertlabs,dc=ibm,dc=com | bawadmin@expertlabs.ibm.com | passw0rd |
| banadmin | uid=banadmin,ou=users,dc=expertlabs,dc=ibm,dc=com | banadmin@expertlabs.ibm.com | passw0rd |
| fnadmin | uid=fnadmin,ou=users,dc=expertlabs,dc=ibm,dc=com | fnadmin@expertlabs.ibm.com | passw0rd |

## Pre-configured Groups

| Group Name | DN | Members |
|------------|-----|---------|
| cp4ba-admins | cn=cp4ba-admins,ou=groups,dc=expertlabs,dc=ibm,dc=com | All admin users |
| odm-admins | cn=odm-admins,ou=groups,dc=expertlabs,dc=ibm,dc=com | All admin users |
| fnwf-admins | cn=fnwf-admins,ou=groups,dc=expertlabs,dc=ibm,dc=com | All admin users |
| fnwfcfg-admins | cn=fnwfcfg-admins,ou=groups,dc=expertlabs,dc=ibm,dc=com | All admin users |

## Troubleshooting

### OpenLDAP Pod Not Starting

Check pod status and events:
```bash
oc describe pod -l app.kubernetes.io/name=openldap -n openldap
```

Check if PVCs are bound:
```bash
oc get pvc -n openldap
```

### Cannot Access phpLDAPadmin

Check if the route is created:
```bash
oc get route phpldapadmin -n openldap
```

Check phpLDAPadmin logs:
```bash
oc logs -f deployment/phpldapadmin -n openldap
```

### LDAP Connection Issues

Test LDAP connectivity from within the cluster:
```bash
oc run ldap-test --image=alpine --rm -it -- sh
apk add openldap-clients
ldapsearch -x -H ldap://openldap-svc.openldap.svc.cluster.local:389 \
  -D "cn=admin,dc=expertlabs,dc=ibm,dc=com" \
  -w passw0rd -b "dc=expertlabs,dc=ibm,dc=com"
```

### Reset LDAP Data

If you need to reset the LDAP data:
```bash
oc delete deployment openldap -n openldap
oc delete pvc openldap-data openldap-config -n openldap
# Then recreate PVCs and deployment
oc apply -f openldap-data-pvc.yaml
oc apply -f openldap-config-pvc.yaml
oc apply -f openldap-deployment.yaml
```

## Adding Custom Users/Groups

### Option 1: Update Bootstrap ConfigMap

Edit `ldap-bootstrap-ldif.yaml` to add more users/groups, then:
```bash
oc apply -f ldap-bootstrap-ldif.yaml
oc delete pod -l app.kubernetes.io/name=openldap -n openldap
```

### Option 2: Use phpLDAPadmin

1. Access phpLDAPadmin web interface
2. Login with admin credentials
3. Navigate to the desired OU
4. Click "Create new entry here"
5. Select template (e.g., "Generic: User Account")
6. Fill in the details and submit

### Option 3: Use LDIF Files

Create an LDIF file with new entries and apply using `ldapadd`:
```bash
oc exec -it deployment/openldap -n openldap -- \
  ldapadd -x -D "cn=admin,dc=expertlabs,dc=ibm,dc=com" \
  -w passw0rd -f /path/to/new-entries.ldif
```

## Cleanup

To remove the entire deployment:

```bash
oc delete route phpldapadmin -n openldap
oc delete deployment phpldapadmin openldap -n openldap
oc delete service phpldapadmin-svc openldap-svc openldap-nodeport -n openldap
oc delete pvc openldap-data openldap-config -n openldap
oc delete configmap ldap-bootstrap -n openldap
oc delete serviceaccount openldap-sa -n openldap
oc delete project openldap
```

## Security Considerations

⚠️ **Important**: This setup uses default passwords and is intended for development/testing purposes only.

For production use:
1. Change all default passwords
2. Enable LDAPS (LDAP over SSL/TLS)
3. Implement proper access controls
4. Use secrets instead of plain text passwords in configurations
5. Enable audit logging
6. Implement backup and disaster recovery procedures
7. Restrict network access using NetworkPolicies

## References

- [OpenLDAP Docker Image](https://github.com/osixia/docker-openldap)
- [phpLDAPadmin Docker Image](https://github.com/osixia/docker-phpLDAPadmin)
- [OpenShift Documentation](https://docs.openshift.com/)
- [LDAP Documentation](https://www.openldap.org/doc/)

## Support

For issues or questions:
- Check the troubleshooting section above
- Review OpenLDAP and phpLDAPadmin logs
- Consult OpenShift cluster administrator

---

**Author**: Nikesh Mewada