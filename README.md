# infra

Infrastructure for my apps. Deployed on push to master via GitHub Actions.

## Subscription-level secret

To generate subscription-scoped credentials for Azure, run:

    az ad sp create-for-rbac --name "bicep" --sdk-auth --role contributor --scopes /subscriptions/sub-id-here

Set the output of the command to GitHub secret variable AZURE_CREDENTIALS.

For more information, see https://docs.microsoft.com/en-us/azure/developer/github/connect-from-azure?tabs=azure-portal%2Clinux#use-the-azure-login-action-with-a-service-principal-secret.
