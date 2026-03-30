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

Create an IAM policy with the minimum permissions needed for the hook:

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

Attach this policy to your IAM user, role, or SSO permission set.

For more restrictive access, limit the `Resource` to the specific model:

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
# Login once
aws sso login --profile your-profile

# Set the profile for Claude Code (in ~/.claude/settings.json)
```

```json
{
  "env": {
    "AWS_PROFILE": "your-profile"
  }
}
```

### Option B: Default Credentials

If you have default credentials configured via `aws configure`, the hook
works without any profile setting.

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

Check model availability in your region:

```bash
aws bedrock list-inference-profiles --region us-west-2 \
  --query "inferenceProfileSummaries[?contains(inferenceProfileId, 'haiku')].inferenceProfileId" \
  --output table
```

## Step 5: Model ID Configuration

The default model is `us.anthropic.claude-haiku-4-5-20251001-v1:0`. Override if needed:

```json
{
  "env": {
    "BEDROCK_MODEL_ID": "us.anthropic.claude-haiku-4-5-20251001-v1:0"
  }
}
```

### Region Prefixes

Model IDs include a region prefix. Use the appropriate one for your region:

| Region | Prefix |
| --- | --- |
| US regions | `us.` |
| EU regions | `eu.` |
| AP regions | `ap.` |

Example: `eu.anthropic.claude-haiku-4-5-20251001-v1:0` for EU regions.

## Troubleshooting

| Issue | Solution |
| --- | --- |
| `ExpiredTokenException` | Re-authenticate: `aws sso login --profile your-profile` |
| `AccessDeniedException` | Check IAM policy has `bedrock:InvokeModel` permission |
| `ValidationException` | Verify model ID is correct and available in your region |
| `ResourceNotFoundException` | Enable model access in the Bedrock console |
| No response from hook | Check `AWS_PROFILE` and `AWS_REGION` are set correctly |

## Cost

Bedrock Haiku pricing (us-east-1):

| | Price |
| --- | --- |
| Input tokens | $0.00080 / 1K tokens |
| Output tokens | $0.00400 / 1K tokens |

Each hook invocation uses ~50 input tokens and ~15 output tokens.
**Cost per call: ~$0.0001** (one hundredth of a cent).
At 200 task completions/month: **~$0.02/month**.

## References

- [Claude Code on Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock)
- [Bedrock Pricing](https://aws.amazon.com/bedrock/pricing/)
- [Bedrock IAM Permissions](https://docs.aws.amazon.com/bedrock/latest/userguide/security-iam.html)
