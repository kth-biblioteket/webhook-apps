# KTH Bibliotekets Webhook-tjänst för Applikationer

## Webhooken får en request från Github actions
```
x-hub-signature-256
```

### Exempel på payload från Github Actions
```
Received payload
{
  event: 'push',
  repository: 'kth-biblioteket/kthb-mailprint-docker',
  commit: '67e4d9fe76bf373f907e86bb95c96b36c801e021',
  ref: 'refs/heads/main',
  head: '',
  workflow: 'Create and publish Docker image',
  data: { action: 'deploy' },
  requestID: '5ef9ddcf-21a3-4b42-ac3b-4334ed703d78'
}
```