{{/* Template used to generate a bucket with s3-operator
Parameters :
- .BucketNamespace : Bucket namespace
- .BucketName : Bucket name
- .BucketQuota : Quota in Bytes
*/}}
{{- define "common.s3bucket" -}}
---
apiVersion: s3.onyxia.sh/v1alpha1
kind: Bucket
metadata:
  name: "{{ .BucketName }}-bucket"
  namespace: {{ .BucketNamespace }}
spec:
  # Bucket name (on S3 server, as opposed to the name of the CR)
  name: {{ .BucketName }}
  quota:
    default: {{ default 1000000000 .BucketQuota }} # Quota defaults to 1GB
    # override: 20000000

---
apiVersion: s3.onyxia.sh/v1alpha1
kind: Policy
metadata:
  name: "{{ .BucketName }}-bucket-policy"
  namespace: {{ .BucketNamespace }}
spec:
  # Policy name (on S3 server, as opposed to the name of the CR)
  name: "{{ .BucketName }}-bucket-policy"
  policyContent: >-
    {
      "Version": "2012-10-17",
      "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "s3:*"
        ],
        "Resource": [
          "arn:aws:s3:::{{ .BucketName }}",
          "arn:aws:s3:::{{ .BucketName }}/*"
        ]
      }
      ]
    }
---
apiVersion: s3.onyxia.sh/v1alpha1
kind: S3User
metadata:
  name: {{ .BucketName }}-s3user
  namespace: {{ .BucketNamespace }}
spec:
  accessKey: {{ .BucketName }}
  policies:
    - "{{ .BucketName }}-bucket-policy"
{{- end -}}