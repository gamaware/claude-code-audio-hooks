# AWS Bedrock Setup for Audio Hooks

This hook uses Amazon Bedrock to invoke Claude Haiku for summarizing task completions
into brief spoken announcements. This guide covers everything needed to configure
Bedrock access.

## Prerequisites

- An AWS account
- AWS CLI v2 installed (`brew install awscli` or [AWS docs](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html))
- Access to Claude models in Bedrock

## Step 1: Enable Model Access

First-time Bedrock users must enable Claude model access:

1. Sign in to the [Amazon Bedrock console](https://console.aws.amazon.com/bedrock/)
2. Navigate to **Model access** in the left sidebar
3. Click **Manage model access**
4. Enable **Anthropic > Claude Haiku** (this is the model used for summarization)
5. Submit the use case form if prompted (first-time only)

Verify model access:

```bash
aws bedrock list-inference-profiles --region us-east-1 \
  --query "inferenceProfileSummaries[?contains(inferenceProfileId, 'haiku') && status=='ACTIVE'].{id:inferenceProfileId,name:inferenceProfileName}" \
  --output table
```

## Step 2: IAM Permissions

Create an IAM policy with the minimum permissions needed:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "BedrockInvokeForAudioHooks",
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream",
        "bedrock:ListInferenceProfiles"
      ],
      "Resource": [
        "arn:aws:bedrock:*:*:inference-profile/*",
        "arn:aws:bedrock:*:*:foundation-model/*"
      ]
    }
  ]
}
```

For more restrictive access, limit to the specific model:

```json
"Resource": [
  "arn:aws:bedrock:us-east-1:*:foundation-model/anthropic.claude-haiku-*",
  "arn:aws:bedrock:us-east-1:*:inference-profile/us.anthropic.claude-haiku-*"
]
```

## Step 3: Configure AWS Credentials

The hook uses the standard AWS SDK credential chain. Choose one method:

### Option A: SSO Profile (recommended)

```bash
aws sso login --profile your-profile
```

```json
{
  "env": {
    "AWS_PROFILE": "your-profile"
  }
}
```

### Option B: Default Credentials

If you have default credentials via `aws configure`, the hook works without
any profile setting.

### Option C: Environment Variables

```bash
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=us-east-1
```

## Step 4: Set Region

The hook defaults to `us-east-1`. Override via environment variable:

```json
{
  "env": {
    "AWS_REGION": "us-west-2"
  }
}
```

### Region Prefixes for Model IDs

| Region | Prefix |
| --- | --- |
| US regions | `us.` |
| EU regions | `eu.` |
| AP regions | `ap.` |

## Cost

| | Price |
| --- | --- |
| Input tokens | $0.00080 / 1K tokens |
| Output tokens | $0.00400 / 1K tokens |
| **Per hook call** | **~$0.0001** |
| **Monthly (200 tasks)** | **~$0.02** |

## Troubleshooting

| Issue | Solution |
| --- | --- |
| `ExpiredTokenException` | `aws sso login --profile your-profile` |
| `AccessDeniedException` | Check IAM policy has `bedrock:InvokeModel` |
| `ValidationException` | Verify model ID and region |
| `ResourceNotFoundException` | Enable model access in Bedrock console |

## References

- [Claude Code on Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
